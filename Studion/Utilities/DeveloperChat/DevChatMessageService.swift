#if DEBUG
import Foundation
import Supabase

/// 한 채팅방의 메시지 로드/전송/실시간 수신. 방을 나가면(`stopListening`) 구독을 끊는다.
@MainActor
@Observable
final class DevChatMessageService {
    private(set) var messages: [DevMessage] = []
    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadMessages(roomID: UUID) async throws {
        messages = try await client
            .from("dev_messages")
            .select()
            .eq("room_id", value: roomID.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func send(body: String, roomID: UUID, senderID: UUID) async throws {
        struct NewMessage: Encodable {
            let room_id: String
            let sender_id: String
            let body: String
        }
        try await client
            .from("dev_messages")
            .insert(NewMessage(room_id: roomID.uuidString, sender_id: senderID.uuidString, body: body))
            .execute()
    }

    /// `dev_messages`의 insert를 이 방으로 필터링해 구독한다.
    /// 채널 등록은 `subscribeWithError()` 호출 **전**에 끝나야 한다.
    func startListening(roomID: UUID) async {
        stopListening()

        let newChannel = client.channel("dev_messages:room_\(roomID.uuidString)")
        let inserts = newChannel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "dev_messages",
            filter: .eq("room_id", value: roomID.uuidString)
        )
        channel = newChannel

        listenTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await newChannel.subscribeWithError()
            } catch {
                return
            }
            for await insert in inserts {
                guard let message = try? insert.decodeRecord(as: DevMessage.self, decoder: Self.decoder) else {
                    continue
                }
                await self.appendIfNew(message)
            }
        }
    }

    func stopListening() {
        listenTask?.cancel()
        listenTask = nil
        if let channel {
            let client = self.client
            Task { await client.removeChannel(channel) }
        }
        channel = nil
    }

    private func appendIfNew(_ message: DevMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
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
