#if DEBUG
import Foundation
import Supabase

/// 한 채팅방의 메시지 로드/전송/리액션/첨부/실시간 수신. 방을 나가면(`stopListening`) 구독을 끊는다.
@MainActor
@Observable
final class DevChatMessageService {
    private(set) var messages: [DevMessage] = []
    /// 메시지 id → 리액션 알약 목록. 메시지와 따로 담는 이유는 리액션만 바뀔 때
    /// 메시지 배열을 건드리지 않아 말풍선 묶음(`DevChatLayout`)을 다시 계산하지 않기 위해서다.
    private(set) var reactions: [UUID: [DevReactionSummary]] = [:]
    /// 실시간 구독이 실패했을 때의 사유. 화면에 띠로 알려 "조용한 방"과 구분한다.
    private(set) var realtimeFailure: String?

    private let client: SupabaseClient
    private let myID: UUID
    private var messageChannel: RealtimeChannelV2?
    private var reactionChannel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?

    /// WorkChat 안드로이드/iOS 퀵 리액션과 동일한 구성.
    static let quickReactionEmojis = ["👍", "❤️", "🙌", "🎉", "😮", "😢", "🔥", "✅"]

    init(client: SupabaseClient, myID: UUID) {
        self.client = client
        self.myID = myID
    }

    // MARK: - 조회

    func loadMessages(roomID: UUID) async throws {
        messages = try await client
            .from("dev_messages")
            .select()
            .eq("room_id", value: roomID.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        await loadReactions()
    }

    /// 지금 로드된 메시지들의 리액션을 한 번에 받아 이모지별로 묶는다.
    ///
    /// 메시지마다 따로 조회하면 왕복이 메시지 수만큼 늘어난다. 팀 규모가 작다는 전제이며,
    /// 대화가 아주 길어지면 방 단위 조회(조인)로 바꾸는 것이 맞다.
    func loadReactions() async {
        let ids = messages.filter { !$0.isDeleted }.map(\.id.uuidString)
        guard !ids.isEmpty else { reactions = [:]; return }

        let rows: [DevReaction]? = try? await client
            .from("dev_message_reactions")
            .select()
            .in("message_id", values: ids)
            .execute()
            .value
        reactions = (rows ?? []).groupedByMessage(myID: myID)
    }

    // MARK: - 전송

    func send(body: String, roomID: UUID, replyToID: UUID? = nil) async throws {
        struct NewMessage: Encodable {
            let room_id: String
            let sender_id: String
            let body: String
            let message_type: String
            let reply_to_id: String?

            // 옵셔널을 컴파일러 기본 구현에 맡기면 nil일 때 키가 빠진다. PostgREST insert는
            // 빠진 키를 열 기본값으로 채우므로 여기서는 문제가 없지만, RPC(dev_create_room)에서
            // 같은 실수로 함수를 못 찾는 버그를 겪었어서 명시적으로 통일해 둔다.
            enum CodingKeys: String, CodingKey {
                case room_id, sender_id, body, message_type, reply_to_id
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(room_id, forKey: .room_id)
                try container.encode(sender_id, forKey: .sender_id)
                try container.encode(body, forKey: .body)
                try container.encode(message_type, forKey: .message_type)
                try container.encode(reply_to_id, forKey: .reply_to_id)
            }
        }

        // 넣은 행을 돌려받아 바로 목록에 붙인다.
        //
        // 실시간 수신에만 맡기면 **내가 보낸 메시지가 화면에 늦게(또는 아예 안) 뜬다** —
        // 구독이 어떤 이유로든 끊겨 있으면 보낸 사람 화면에서만 사라진 것처럼 보인다.
        // 실제로 겪었다(리액션 테이블이 발행 목록에 없어 채널 전체가 죽은 경우).
        let inserted: DevMessage = try await client
            .from("dev_messages")
            .insert(NewMessage(
                room_id: roomID.uuidString,
                sender_id: myID.uuidString,
                body: body,
                message_type: DevMessageType.text.rawValue,
                reply_to_id: replyToID?.uuidString
            ))
            .select()
            .single()
            .execute()
            .value
        appendIfNew(inserted)
    }

    /// 사진/파일을 Storage에 올리고 그 경로를 담은 메시지를 만든다.
    ///
    /// 업로드가 성공해도 메시지 insert가 실패할 수 있다 — 그 경우 버킷에 주인 없는 파일이
    /// 남는다. 개발용 도구라 청소는 하지 않고, 실패를 호출부로 던져 사용자에게 알린다.
    func sendAttachment(
        data: Data,
        fileName: String,
        mimeType: String,
        type: DevMessageType,
        roomID: UUID
    ) async throws {
        // 경로 첫 폴더가 방 id여야 버킷 정책이 통과된다 (→ 004 SQL).
        let ext = (fileName as NSString).pathExtension
        let path = "\(roomID.uuidString)/\(UUID().uuidString)\(ext.isEmpty ? "" : ".\(ext)")"

        try await client.storage
            .from(DevChatStorage.bucket)
            .upload(path, data: data, options: FileOptions(contentType: mimeType))

        struct NewAttachmentMessage: Encodable {
            let room_id: String
            let sender_id: String
            let body: String
            let message_type: String
            let attachment_path: String
            let attachment_name: String
            let attachment_size: Int
            let attachment_mime: String
        }

        let inserted: DevMessage = try await client
            .from("dev_messages")
            .insert(NewAttachmentMessage(
                room_id: roomID.uuidString,
                sender_id: myID.uuidString,
                body: "",
                message_type: type.rawValue,
                attachment_path: path,
                attachment_name: fileName,
                attachment_size: data.count,
                attachment_mime: mimeType
            ))
            .select()
            .single()
            .execute()
            .value
        // 방금 올린 바이트를 캐시에 미리 넣어둔다 — 다시 내려받지 않고 바로 보인다.
        DevChatStorage.shared.prime(path: path, data: data)
        appendIfNew(inserted)
    }

    // MARK: - 수정 / 삭제

    func edit(_ message: DevMessage, newBody: String) async throws {
        struct Patch: Encodable {
            let body: String
            let edited_at: String
        }
        try await client
            .from("dev_messages")
            .update(Patch(body: newBody, edited_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: message.id.uuidString)
            .execute()
        await reload(message.id)
    }

    /// 행을 지우지 않고 `deleted_at`만 세운다 — 목록에 "삭제된 메시지"로 남겨야 하고,
    /// 그 메시지에 달린 답장도 무엇에 대한 답인지 알 수 있어야 한다.
    func delete(_ message: DevMessage) async throws {
        struct Patch: Encodable { let deleted_at: String }
        try await client
            .from("dev_messages")
            .update(Patch(deleted_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: message.id.uuidString)
            .execute()
        await reload(message.id)
    }

    /// 한 메시지만 다시 읽어 목록에 반영한다(수정·삭제 직후).
    private func reload(_ messageID: UUID) async {
        let rows: [DevMessage]? = try? await client
            .from("dev_messages")
            .select()
            .eq("id", value: messageID.uuidString)
            .execute()
            .value
        guard let updated = rows?.first,
              let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index] = updated
    }

    // MARK: - 리액션

    /// 이미 내가 누른 이모지면 취소하고, 아니면 추가한다.
    ///
    /// 서버 응답을 기다리지 않고 화면을 먼저 바꾼다 — 이모지를 눌렀는데 반응이 늦으면
    /// 눌리지 않은 것처럼 느껴진다. 실패하면 다시 읽어 되돌린다.
    func toggleReaction(_ message: DevMessage, emoji: String) async {
        let mine = reactions[message.id]?.first { $0.emoji == emoji }?.reactedByMe ?? false
        applyLocalReaction(messageID: message.id, emoji: emoji, adding: !mine)

        do {
            if mine {
                try await client
                    .from("dev_message_reactions")
                    .delete()
                    .eq("message_id", value: message.id.uuidString)
                    .eq("user_id", value: myID.uuidString)
                    .eq("emoji", value: emoji)
                    .execute()
            } else {
                struct NewReaction: Encodable {
                    let message_id: String
                    let user_id: String
                    let emoji: String
                }
                try await client
                    .from("dev_message_reactions")
                    .insert(NewReaction(
                        message_id: message.id.uuidString,
                        user_id: myID.uuidString,
                        emoji: emoji
                    ))
                    .execute()
            }
        } catch {
            // 실패하면 서버 값으로 되돌린다.
            await loadReactions()
        }
    }

    /// 낙관적 갱신 — 서버에 다녀오기 전에 알약을 먼저 바꾼다.
    private func applyLocalReaction(messageID: UUID, emoji: String, adding: Bool) {
        var list = reactions[messageID] ?? []

        if let index = list.firstIndex(where: { $0.emoji == emoji }) {
            let existing = list[index]
            let newCount = existing.count + (adding ? 1 : -1)
            if newCount <= 0 {
                list.remove(at: index)
            } else {
                list[index] = DevReactionSummary(
                    emoji: emoji,
                    count: newCount,
                    reactedByMe: adding,
                    userIDs: adding
                        ? existing.userIDs + [myID]
                        : existing.userIDs.filter { $0 != myID }
                )
            }
        } else if adding {
            list.append(DevReactionSummary(emoji: emoji, count: 1, reactedByMe: true, userIDs: [myID]))
        }

        // 정렬 규칙은 서버에서 다시 받을 때와 같아야 한다 — 안 그러면 알약이 잠깐 다른 자리로 튄다.
        reactions[messageID] = list.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.emoji < $1.emoji
        }
    }

    // MARK: - 읽음 표시

    func markRead(roomID: UUID) async {
        struct Params: Encodable { let target_room_id: String }
        _ = try? await client
            .rpc("dev_mark_room_read", params: Params(target_room_id: roomID.uuidString))
            .execute()
    }

    // MARK: - 실시간

    /// 메시지와 리액션 변경을 구독한다.
    ///
    /// **메시지와 리액션을 서로 다른 채널에 둔다.** 한 채널에 얹으면 한쪽 구독이 잘못돼도
    /// 채널 전체의 이벤트가 끊긴다 — 리액션 테이블을 Realtime 발행 목록에 넣지 않은 채
    /// 같은 채널에 얹었더니, 구독은 성공했다고 나오면서 **메시지 이벤트까지 조용히
    /// 오지 않았다**(실제로 겪은 버그, → `005_realtime_reactions.sql`).
    /// 채널을 나누면 리액션 쪽이 죽어도 메시지는 계속 온다.
    ///
    /// 채널 등록(`postgresChange`)은 `subscribeWithError()` 호출 **전**에 끝나야 한다.
    func startListening(roomID: UUID) async {
        stopListening()
        realtimeFailure = nil

        let messages = client.channel("dev_messages:room_\(roomID.uuidString)")
        let inserts = messages.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "dev_messages",
            filter: .eq("room_id", value: roomID.uuidString)
        )
        // 수정·삭제도 받아야 상대가 지운 메시지가 내 화면에서도 "삭제된 메시지"로 바뀐다.
        let updates = messages.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "dev_messages",
            filter: .eq("room_id", value: roomID.uuidString)
        )

        // 리액션은 방으로 필터링할 수 없다(테이블에 room_id가 없다) — 전체를 받아
        // 지금 보고 있는 메시지의 것만 다시 읽는다.
        let reactionsChannel = client.channel("dev_reactions:room_\(roomID.uuidString)")
        let reactionInserts = reactionsChannel.postgresChange(
            InsertAction.self, schema: "public", table: "dev_message_reactions"
        )
        let reactionDeletes = reactionsChannel.postgresChange(
            DeleteAction.self, schema: "public", table: "dev_message_reactions"
        )

        messageChannel = messages
        reactionChannel = reactionsChannel

        listenTask = Task { [weak self] in
            guard let self else { return }
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    do {
                        try await messages.subscribeWithError()
                    } catch {
                        // 메시지 구독 실패는 사용자에게 알린다 — 안 알리면 상대가 조용한
                        // 것과 구분되지 않는다.
                        await self?.reportRealtimeFailure(error)
                        return
                    }
                    // 디코딩까지 메인 액터에서 한다 — `decoder`가 메인 액터에 격리돼 있고
                    // JSONDecoder를 여러 스레드에서 동시에 쓰는 것은 보장된 동작이 아니다.
                    await withTaskGroup(of: Void.self) { inner in
                        inner.addTask { [weak self] in
                            for await insert in inserts { await self?.receiveInsert(insert) }
                        }
                        inner.addTask { [weak self] in
                            for await update in updates { await self?.receiveUpdate(update) }
                        }
                    }
                }

                group.addTask { [weak self] in
                    // 리액션 구독이 실패해도 메시지는 계속 와야 하므로 여기서는 알리지 않는다.
                    // 알약은 방을 다시 열 때 조회로 채워진다.
                    guard (try? await reactionsChannel.subscribeWithError()) != nil else { return }
                    await withTaskGroup(of: Void.self) { inner in
                        inner.addTask { [weak self] in
                            for await _ in reactionInserts { await self?.loadReactions() }
                        }
                        inner.addTask { [weak self] in
                            for await _ in reactionDeletes { await self?.loadReactions() }
                        }
                    }
                }
            }
        }
    }

    func stopListening() {
        listenTask?.cancel()
        listenTask = nil
        let client = self.client
        for channel in [messageChannel, reactionChannel].compactMap({ $0 }) {
            Task { await client.removeChannel(channel) }
        }
        messageChannel = nil
        reactionChannel = nil
    }

    private func reportRealtimeFailure(_ error: any Error) {
        realtimeFailure = error.localizedDescription
    }

    private func receiveInsert(_ action: InsertAction) {
        guard let message = try? action.decodeRecord(
            as: DevMessage.self, decoder: Self.decoder
        ) else { return }
        appendIfNew(message)
    }

    private func receiveUpdate(_ action: UpdateAction) {
        guard let message = try? action.decodeRecord(
            as: DevMessage.self, decoder: Self.decoder
        ) else { return }
        replaceIfPresent(message)
    }

    private func appendIfNew(_ message: DevMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
    }

    private func replaceIfPresent(_ message: DevMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index] = message
    }

    /// Postgres `timestamptz`가 소수점 초 유무를 오갈 수 있어 두 형식을 모두 받는다.
    private static let decoder: JSONDecoder = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let whole = ISO8601DateFormatter()
        whole.formatOptions = [.withInternetDateTime]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { valueDecoder in
            let container = try valueDecoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = withFractional.date(from: string) ?? whole.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "잘못된 날짜 형식: \(string)"
            )
        }
        return decoder
    }()
}
#endif
