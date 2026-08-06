import Foundation

/// `docs/10-developer-chat.md` §3의 테이블과 1:1 대응한다.
struct DevProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    /// `006_add_profile_email.sql` 이전에 만든 서버에는 이 컬럼이 없을 수 있어 옵셔널로 둔다.
    var email: String?
    /// 프로필 사진의 Storage 경로 (`dev-avatars` 버킷 안 `<user_id>/<uuid>.jpg`).
    /// 사진을 안 올렸으면 nil이고, 그때는 이름 첫 글자 아바타를 쓴다.
    /// → `009_profile_avatar.sql`
    var avatarPath: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case avatarPath = "avatar_path"
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

/// 메시지 종류. 첨부가 붙으면 본문이 비어 있을 수 있다.
enum DevMessageType: String, Codable {
    case text = "TEXT"
    case image = "IMAGE"
    case file = "FILE"
}

struct DevMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let roomId: UUID
    let senderId: UUID
    var body: String
    let createdAt: Date

    /// 서버 기본값이 `TEXT`라 옵셔널로 두지 않는다.
    var messageType: DevMessageType = .text
    /// Storage 버킷 안의 경로. 규칙은 `<room_id>/<uuid>.<ext>` — 버킷 정책이 첫 폴더명을
    /// 방 id로 읽어 접근 권한을 검사한다 (→ `004_reactions_attachments.sql`).
    var attachmentPath: String?
    var attachmentName: String?
    var attachmentSize: Int?
    var attachmentMime: String?
    var replyToId: UUID?
    /// 지운 메시지도 행은 남는다 — "삭제된 메시지"로 표시하기 위해서다.
    var deletedAt: Date?
    var editedAt: Date?

    var isDeleted: Bool { deletedAt != nil }

    /// 사진 말풍선으로 그릴 수 있는 상태인지.
    var hasImage: Bool {
        !isDeleted && messageType == .image && attachmentPath != nil
    }

    enum CodingKeys: String, CodingKey {
        case id, body
        case roomId = "room_id"
        case senderId = "sender_id"
        case createdAt = "created_at"
        case messageType = "message_type"
        case attachmentPath = "attachment_path"
        case attachmentName = "attachment_name"
        case attachmentSize = "attachment_size"
        case attachmentMime = "attachment_mime"
        case replyToId = "reply_to_id"
        case deletedAt = "deleted_at"
        case editedAt = "edited_at"
    }
}

/// 리액션 한 건(누가 어떤 이모지를 남겼는지). 화면에는 이걸 이모지별로 묶은
/// `DevReactionSummary`를 쓴다.
struct DevReaction: Codable, Hashable {
    let messageId: UUID
    let userId: UUID
    let emoji: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case userId = "user_id"
        case emoji
    }
}

/// 말풍선 아래 표시할 리액션 알약 하나.
struct DevReactionSummary: Identifiable, Hashable {
    let emoji: String
    let count: Int
    /// 내가 누른 리액션인지 — 눌렀으면 강조하고, 다시 탭하면 취소된다.
    let reactedByMe: Bool
    /// 누가 남겼는지 보여주는 시트용.
    let userIDs: [UUID]

    var id: String { emoji }
}

extension Array where Element == DevReaction {
    /// 리액션 목록을 메시지별·이모지별로 묶는다. 이모지 정렬은 개수 내림차순 →
    /// 같은 개수면 이모지 문자열 순으로 고정한다(순서가 매번 바뀌면 눌렀던 자리가 흔들린다).
    func groupedByMessage(myID: UUID) -> [UUID: [DevReactionSummary]] {
        let byMessage = Dictionary(grouping: self, by: \.messageId)
        return byMessage.mapValues { reactions in
            Dictionary(grouping: reactions, by: \.emoji)
                .map { emoji, items in
                    DevReactionSummary(
                        emoji: emoji,
                        count: items.count,
                        reactedByMe: items.contains { $0.userId == myID },
                        userIDs: items.map(\.userId)
                    )
                }
                .sorted {
                    $0.count != $1.count ? $0.count > $1.count : $0.emoji < $1.emoji
                }
        }
    }
}
