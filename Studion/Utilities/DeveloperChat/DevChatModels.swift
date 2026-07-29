#if DEBUG
import Foundation

/// `docs/10-developer-chat.md` §3의 테이블과 1:1 대응한다.
struct DevProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

struct DevChatRoom: Codable, Identifiable, Hashable {
    let id: UUID
    /// 그룹 방만 쓴다. 1:1 방은 상대방 이름을 클라이언트가 표시한다.
    var name: String?
    var isGroup: Bool
    var createdBy: UUID
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case isGroup = "is_group"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct DevChatRoomMember: Codable, Hashable {
    let roomId: UUID
    let userId: UUID
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

struct DevMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let roomId: UUID
    let senderId: UUID
    var body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body
        case roomId = "room_id"
        case senderId = "sender_id"
        case createdAt = "created_at"
    }
}
#endif
