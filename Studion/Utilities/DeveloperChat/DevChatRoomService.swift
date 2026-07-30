#if DEBUG
import Foundation
import Supabase

/// 채팅방 목록·생성·초대. 팀 규모가 작다는 전제로 유저 검색은 서버 필터 없이
/// 전체 프로필을 받아 클라이언트에서 거른다 (→ `docs/10-developer-chat.md` §1).
@MainActor
@Observable
final class DevChatRoomService {
    private(set) var rooms: [DevChatRoom] = []
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadRooms() async throws {
        // RLS가 "내가 멤버인 방"만 걸러준다 — 여기서 조건을 추가로 걸 필요가 없다.
        rooms = try await client
            .from("dev_chat_rooms")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// 방별 안 읽은 개수. 내가 보낸 메시지와 지운 메시지는 세지 않는다(계산은 서버 함수가 한다).
    func unreadCounts() async -> [UUID: Int] {
        struct Row: Decodable {
            let room_id: UUID
            let unread_count: Int
        }
        let rows: [Row]? = try? await client
            .rpc("dev_unread_counts")
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: (rows ?? []).map { ($0.room_id, $0.unread_count) })
    }

    func allProfiles() async throws -> [DevProfile] {
        try await client
            .from("dev_profiles")
            .select()
            .order("display_name", ascending: true)
            .execute()
            .value
    }

    /// 방마다 가장 최근 메시지. 대화 목록의 미리보기·시각에 쓴다.
    ///
    /// 방마다 따로 질의하면 방 수만큼 왕복하므로 한 번에 받아 클라이언트에서 가른다.
    /// 팀 규모와 방 개수가 작다는 전제이며, 그 전제가 깨지면 방별 최근 메시지를
    /// 돌려주는 뷰나 RPC를 두는 것이 맞다.
    func lastMessages(for roomIDs: [UUID]) async throws -> [UUID: DevMessage] {
        guard !roomIDs.isEmpty else { return [:] }

        let recent: [DevMessage] = try await client
            .from("dev_messages")
            .select()
            .in("room_id", values: roomIDs.map(\.uuidString))
            .order("created_at", ascending: false)
            .limit(500)
            .execute()
            .value

        // 내림차순이라 방마다 처음 만나는 것이 가장 최근이다.
        return recent.reduce(into: [:]) { result, message in
            if result[message.roomId] == nil {
                result[message.roomId] = message
            }
        }
    }

    func members(of roomID: UUID) async throws -> [DevProfile] {
        struct MemberRow: Decodable { let user_id: UUID }

        let memberRows: [MemberRow] = try await client
            .from("dev_chat_room_members")
            .select("user_id")
            .eq("room_id", value: roomID.uuidString)
            .execute()
            .value
        guard !memberRows.isEmpty else { return [] }

        let memberIDs = Set(memberRows.map(\.user_id))
        let profiles = try await allProfiles()
        return profiles.filter { memberIDs.contains($0.id) }
    }

    /// `dev_create_room` RPC를 호출한다 — 방 생성과 생성자 멤버 등록이 한 트랜잭션으로 묶인다.
    /// 필드 이름은 일부러 snake_case다. SQL 함수의 파라미터 이름과 정확히 일치해야 한다.
    @discardableResult
    func createRoom(name: String?, isGroup: Bool, memberIDs: [UUID]) async throws -> UUID {
        struct Params: Encodable {
            let room_name: String?
            let is_group: Bool
            let member_ids: [String]

            // `encode(to:)`를 직접 쓰면 컴파일러가 CodingKeys를 만들어주지 않으므로 직접 선언한다.
            enum CodingKeys: String, CodingKey {
                case room_name, is_group, member_ids
            }

            // `encode(to:)`를 직접 쓴다. 컴파일러가 만들어주는 구현은 옵셔널에
            // `encodeIfPresent`를 써서 `room_name`이 nil이면 키를 아예 빼버린다.
            // PostgREST는 넘어온 인자 이름으로 함수를 찾으므로, 1:1 방(이름 없음)을
            // 만들 때 인자가 2개인 함수를 찾다가 실패한다 (겪은 버그).
            // null을 명시적으로 실어 보내야 3개 인자 함수에 매칭된다.
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(room_name, forKey: .room_name)
                try container.encode(is_group, forKey: .is_group)
                try container.encode(member_ids, forKey: .member_ids)
            }
        }
        let params = Params(
            room_name: name,
            is_group: isGroup,
            member_ids: memberIDs.map(\.uuidString)
        )
        let newRoomID: UUID = try await client
            .rpc("dev_create_room", params: params)
            .execute()
            .value
        try await loadRooms()
        return newRoomID
    }

    func invite(userID: UUID, to roomID: UUID) async throws {
        struct NewMember: Encodable {
            let room_id: String
            let user_id: String
        }
        try await client
            .from("dev_chat_room_members")
            .insert(NewMember(room_id: roomID.uuidString, user_id: userID.uuidString))
            .execute()
    }
}
#endif
