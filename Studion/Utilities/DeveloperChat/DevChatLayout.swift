#if DEBUG
import Foundation

/// 메시지 목록을 화면 행으로 묶는 계산. SwiftUI를 import하지 않는다 — 뷰가 "여기에 날짜를
/// 넣어야 하나", "이 사진들을 한 앨범으로 묶나"를 각자 판단하지 않도록 여기서 한 번만 정한다.
///
/// 규칙은 WorkChat iOS(`clients/ios/WorkChat/Features/MessageView.swift`)를 따른다:
/// 날짜가 바뀌면 날짜 구분선, 보낸 사람이 바뀌면 이름·아바타, 시각은 모든 말풍선에.
///
/// → `docs/10-developer-chat.md` §6
enum DevChatLayout {

    /// 연속된 사진을 한 앨범으로 묶는 시간 간격.
    static let photoGroupInterval: TimeInterval = 300

    /// 한 행에 그릴 내용.
    enum Content: Equatable {
        /// 말풍선 하나(텍스트·파일·단일 사진·삭제된 메시지).
        case single(DevMessage)
        /// 연속으로 온 같은 사람의 사진 묶음 — 2장 이상일 때만 만든다.
        case photoGroup([DevMessage])
    }

    struct Row: Identifiable, Equatable {
        let content: Content
        /// 이 행 **위**에 표시할 날짜. `nil`이면 표시하지 않는다.
        let dateSeparator: Date?
        /// 보낸 사람 이름과 아바타를 표시할지 — 날짜가 바뀌거나 보낸 사람이 바뀔 때만 true.
        let showsSender: Bool

        var first: DevMessage {
            switch content {
            case .single(let message): return message
            case .photoGroup(let group): return group[0]
            }
        }

        var last: DevMessage {
            switch content {
            case .single(let message): return message
            case .photoGroup(let group): return group[group.count - 1]
            }
        }

        var id: UUID { first.id }
    }

    /// 시각순으로 정렬된 메시지를 행으로 묶는다.
    static func rows(for messages: [DevMessage], calendar: Calendar = .current) -> [Row] {
        guard !messages.isEmpty else { return [] }

        let grouped = groupPhotos(in: messages, calendar: calendar)

        return grouped.enumerated().map { index, content in
            let first: DevMessage
            switch content {
            case .single(let message): first = message
            case .photoGroup(let group): first = group[0]
            }

            let previous: DevMessage? = index > 0 ? lastMessage(of: grouped[index - 1]) : nil
            let isNewDay = previous.map {
                !calendar.isDate($0.createdAt, inSameDayAs: first.createdAt)
            } ?? true

            return Row(
                content: content,
                dateSeparator: isNewDay ? first.createdAt : nil,
                // 날짜가 바뀌면 보낸 사람이 같아도 이름을 다시 보여준다 — 구분선 아래 첫 줄이
                // 이름 없이 시작하면 누가 말하는지 모르는 채로 새 날이 시작된다.
                showsSender: isNewDay || previous?.senderId != first.senderId
            )
        }
    }

    private static func lastMessage(of content: Content) -> DevMessage {
        switch content {
        case .single(let message): return message
        case .photoGroup(let group): return group[group.count - 1]
        }
    }

    /// 답장이 달리지 않은, 지워지지 않은 사진들을 같은 사람·같은 날·5분 이내 기준으로 묶는다.
    ///
    /// 1장만 남으면 앨범으로 만들지 않는다 — 앨범에는 컨텍스트 메뉴(답장·리액션·삭제)를 달지
    /// 않으므로, 1장짜리를 앨범으로 만들면 사진 한 장에 리액션을 못 남기게 된다.
    private static func groupPhotos(in messages: [DevMessage], calendar: Calendar) -> [Content] {
        var result: [Content] = []
        var index = 0

        while index < messages.count {
            let message = messages[index]
            guard isGroupable(message) else {
                result.append(.single(message))
                index += 1
                continue
            }

            var group = [message]
            var next = index + 1
            while next < messages.count,
                  isGroupable(messages[next]),
                  messages[next].senderId == message.senderId,
                  let previous = group.last,
                  calendar.isDate(previous.createdAt, inSameDayAs: messages[next].createdAt),
                  messages[next].createdAt.timeIntervalSince(previous.createdAt) <= photoGroupInterval {
                group.append(messages[next])
                next += 1
            }

            result.append(group.count > 1 ? .photoGroup(group) : .single(message))
            index = next
        }
        return result
    }

    private static func isGroupable(_ message: DevMessage) -> Bool {
        message.hasImage && message.replyToId == nil
    }
}
#endif
