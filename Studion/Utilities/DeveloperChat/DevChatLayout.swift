#if DEBUG
import Foundation

/// 메시지 목록을 애플 메시지처럼 배치하기 위한 계산. SwiftUI를 import하지 않는다 —
/// 뷰가 각자 "이 말풍선에 꼬리를 달아야 하나"를 판단하지 않도록 여기서 한 번만 정한다.
///
/// → `docs/10-developer-chat.md` §6
enum DevChatLayout {

    /// 같은 사람이 이 시간 안에 연달아 보내면 한 묶음으로 본다.
    static let groupingInterval: TimeInterval = 60 * 5
    /// 이만큼 벌어지면 그 위에 시각 구분선을 넣는다.
    static let separatorInterval: TimeInterval = 60 * 60

    /// 화면에 그릴 한 줄.
    struct Row: Identifiable, Equatable {
        let message: DevMessage
        /// 이 메시지 **위에** 표시할 시각. `nil`이면 표시하지 않는다.
        let timeSeparator: Date?
        /// 연속 묶음의 첫 메시지 — 그룹 대화에서 보낸 사람 이름을 여기에 붙인다.
        let isGroupHead: Bool
        /// 연속 묶음의 마지막 메시지 — **여기에만** 말풍선 꼬리를 붙인다.
        /// 애플 메시지도 묶음의 마지막에만 꼬리가 있다.
        let isGroupTail: Bool

        var id: UUID { message.id }
    }

    /// 시각순으로 정렬된 메시지를 받아 배치 정보를 채운다.
    ///
    /// 묶음이 끊기는 조건은 두 가지다: 보낸 사람이 바뀌거나, 시각 구분선이 들어가거나.
    /// 구분선이 들어간 자리에서 묶음을 이어가면 구분선이 말풍선 꼬리 사이에 끼어
    /// 어색해지므로 반드시 끊는다.
    static func rows(for messages: [DevMessage]) -> [Row] {
        guard !messages.isEmpty else { return [] }

        // 1단계: 어디에 구분선이 들어가는지 먼저 정한다. 묶음 판단이 이 결과에 의존한다.
        let separators: [Date?] = messages.enumerated().map { index, message in
            guard index > 0 else { return message.createdAt }  // 첫 메시지 위에는 항상 넣는다
            let gap = message.createdAt.timeIntervalSince(messages[index - 1].createdAt)
            return gap >= separatorInterval ? message.createdAt : nil
        }

        // 2단계: 앞뒤와 묶이는지 본다.
        return messages.indices.map { index in
            return Row(
                message: messages[index],
                timeSeparator: separators[index],
                isGroupHead: separators[index] != nil
                    || !continues(from: index - 1, to: index, in: messages),
                isGroupTail: index == messages.indices.last
                    || separators[index + 1] != nil
                    || !continues(from: index, to: index + 1, in: messages)
            )
        }
    }

    /// `from`에서 `to`로 묶음이 이어지는가. 범위를 벗어나면 이어지지 않는다.
    private static func continues(from: Int, to: Int, in messages: [DevMessage]) -> Bool {
        guard messages.indices.contains(from), messages.indices.contains(to) else { return false }
        let earlier = messages[from]
        let later = messages[to]
        guard earlier.senderId == later.senderId else { return false }
        return later.createdAt.timeIntervalSince(earlier.createdAt) <= groupingInterval
    }
}
#endif
