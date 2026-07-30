#if DEBUG
import Foundation
import Testing
@testable import Studion

/// 애플 메시지식 배치 규칙 — 묶음과 시각 구분선.
@Suite("개발자 메신저 말풍선 배치")
struct DevChatLayoutTests {

    private let alice = UUID()
    private let bob = UUID()
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// `offset`초 뒤에 `sender`가 보낸 메시지.
    private func message(_ sender: UUID, _ offset: TimeInterval, _ body: String = "테스트") -> DevMessage {
        DevMessage(
            id: UUID(),
            roomId: UUID(),
            senderId: sender,
            body: body,
            createdAt: base.addingTimeInterval(offset)
        )
    }

    @Test("메시지가 없으면 빈 배열이다")
    func emptyInput() {
        #expect(DevChatLayout.rows(for: []).isEmpty)
    }

    @Test("첫 메시지 위에는 항상 시각을 넣는다")
    func firstMessageAlwaysHasSeparator() {
        let rows = DevChatLayout.rows(for: [message(alice, 0)])
        #expect(rows.count == 1)
        #expect(rows[0].timeSeparator == base)
    }

    @Test("같은 사람이 곧바로 이어 보내면 한 묶음이다")
    func consecutiveMessagesGroup() {
        let rows = DevChatLayout.rows(for: [
            message(alice, 0),
            message(alice, 30),
            message(alice, 60),
        ])

        #expect(rows.map(\.isGroupHead) == [true, false, false])
        // 꼬리는 묶음의 마지막에만.
        #expect(rows.map(\.isGroupTail) == [false, false, true])
    }

    @Test("보낸 사람이 바뀌면 묶음이 끊긴다")
    func senderChangeBreaksGroup() {
        let rows = DevChatLayout.rows(for: [
            message(alice, 0),
            message(bob, 10),
            message(alice, 20),
        ])

        // 셋 다 혼자인 묶음이라 전부 처음이면서 끝이다.
        #expect(rows.map(\.isGroupHead) == [true, true, true])
        #expect(rows.map(\.isGroupTail) == [true, true, true])
    }

    @Test("묶음 간격을 넘겨 보내면 같은 사람이어도 끊긴다")
    func groupingIntervalBreaksGroup() {
        let justOver = DevChatLayout.groupingInterval + 1
        let rows = DevChatLayout.rows(for: [
            message(alice, 0),
            message(alice, justOver),
        ])

        #expect(rows.map(\.isGroupHead) == [true, true])
        #expect(rows.map(\.isGroupTail) == [true, true])
    }

    @Test("묶음 간격 경계값은 아직 한 묶음이다")
    func groupingIntervalBoundaryStaysGrouped() {
        let rows = DevChatLayout.rows(for: [
            message(alice, 0),
            message(alice, DevChatLayout.groupingInterval),
        ])

        #expect(rows.map(\.isGroupHead) == [true, false])
        #expect(rows.map(\.isGroupTail) == [false, true])
    }

    @Test("시간이 많이 벌어지면 그 위에 시각을 넣는다")
    func longGapInsertsSeparator() {
        let gap = DevChatLayout.separatorInterval
        let rows = DevChatLayout.rows(for: [
            message(alice, 0),
            message(alice, gap),
        ])

        #expect(rows[1].timeSeparator == base.addingTimeInterval(gap))
    }

    @Test("가까운 간격에는 시각을 넣지 않는다")
    func shortGapHasNoSeparator() {
        let rows = DevChatLayout.rows(for: [
            message(alice, 0),
            message(alice, 30),
        ])

        #expect(rows[1].timeSeparator == nil)
    }

    @Test("시각 구분선이 들어가면 같은 사람이어도 묶음이 끊긴다")
    func separatorBreaksGroup() {
        // 구분선을 사이에 두고 묶음이 이어지면 구분선이 꼬리 없는 말풍선들 사이에 끼어
        // 어색해진다. 구분선 위 메시지는 반드시 묶음의 마지막이어야 한다.
        let rows = DevChatLayout.rows(for: [
            message(alice, 0),
            message(alice, DevChatLayout.separatorInterval),
        ])

        #expect(rows[0].isGroupTail)
        #expect(rows[1].isGroupHead)
    }

    @Test("묶음이 여러 개 섞여도 각 묶음의 처음과 끝을 정확히 찾는다")
    func mixedConversation() {
        let rows = DevChatLayout.rows(for: [
            message(alice, 0),     // 묶음 1 시작·끝 아님
            message(alice, 10),    // 묶음 1 끝
            message(bob, 20),      // 묶음 2 (혼자)
            message(alice, 30),    // 묶음 3 시작
            message(alice, 40),    // 묶음 3 끝
        ])

        #expect(rows.map(\.isGroupHead) == [true, false, true, true, false])
        #expect(rows.map(\.isGroupTail) == [false, true, true, false, true])
    }

    @Test("행 id는 메시지 id를 그대로 쓴다 — ForEach가 재사용할 수 있어야 한다")
    func rowIDMatchesMessageID() {
        let one = message(alice, 0)
        let rows = DevChatLayout.rows(for: [one])
        #expect(rows[0].id == one.id)
    }
}
#endif
