#if DEBUG
import Foundation
import Testing
@testable import Studion

/// 채팅 행 묶음 규칙 — 날짜 구분선, 보낸 사람 표시, 사진 앨범 묶기.
/// WorkChat iOS와 같은 규칙을 따른다(→ docs/10 §6).
@Suite("개발자 메신저 채팅 배치")
struct DevChatLayoutTests {

    private let alice = UUID()
    private let bob = UUID()
    private let room = UUID()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        // 날짜 경계가 시간대에 따라 달라지므로 고정한다.
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    /// 2026-07-30 12:00 KST 기준.
    private func date(day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    private func text(_ sender: UUID, _ when: Date, body: String = "안녕") -> DevMessage {
        DevMessage(id: UUID(), roomId: room, senderId: sender, body: body, createdAt: when)
    }

    private func photo(_ sender: UUID, _ when: Date, replyTo: UUID? = nil) -> DevMessage {
        var message = DevMessage(
            id: UUID(), roomId: room, senderId: sender, body: "", createdAt: when)
        message.messageType = .image
        message.attachmentPath = "\(room.uuidString)/\(UUID().uuidString).jpg"
        message.replyToId = replyTo
        return message
    }

    // MARK: 날짜 구분선

    @Test("메시지가 없으면 빈 배열이다")
    func emptyInput() {
        #expect(DevChatLayout.rows(for: [], calendar: calendar).isEmpty)
    }

    @Test("첫 메시지 위에는 항상 날짜를 넣는다")
    func firstRowHasDate() {
        let rows = DevChatLayout.rows(for: [text(alice, date(day: 30))], calendar: calendar)
        #expect(rows.count == 1)
        #expect(rows[0].dateSeparator != nil)
    }

    @Test("같은 날 메시지에는 날짜를 다시 넣지 않는다")
    func sameDayHasNoExtraDate() {
        let rows = DevChatLayout.rows(for: [
            text(alice, date(day: 30, hour: 9)),
            text(alice, date(day: 30, hour: 21)),
        ], calendar: calendar)

        #expect(rows[0].dateSeparator != nil)
        #expect(rows[1].dateSeparator == nil)
    }

    @Test("날이 바뀌면 날짜를 넣는다")
    func newDayInsertsDate() {
        let rows = DevChatLayout.rows(for: [
            text(alice, date(day: 29, hour: 23)),
            text(alice, date(day: 30, hour: 1)),
        ], calendar: calendar)

        #expect(rows[1].dateSeparator != nil)
    }

    // MARK: 보낸 사람 표시

    @Test("같은 사람이 이어 보내면 이름을 한 번만 보여준다")
    func senderShownOncePerRun() {
        let rows = DevChatLayout.rows(for: [
            text(alice, date(day: 30, hour: 9)),
            text(alice, date(day: 30, hour: 9, minute: 1)),
            text(alice, date(day: 30, hour: 9, minute: 2)),
        ], calendar: calendar)

        #expect(rows.map(\.showsSender) == [true, false, false])
    }

    @Test("보낸 사람이 바뀌면 이름을 다시 보여준다")
    func senderChangeShowsSender() {
        let rows = DevChatLayout.rows(for: [
            text(alice, date(day: 30, hour: 9)),
            text(bob, date(day: 30, hour: 9, minute: 1)),
            text(alice, date(day: 30, hour: 9, minute: 2)),
        ], calendar: calendar)

        #expect(rows.map(\.showsSender) == [true, true, true])
    }

    @Test("시간이 많이 벌어져도 같은 사람·같은 날이면 이름을 다시 보여주지 않는다")
    func longGapSameDayKeepsSenderHidden() {
        // 시각은 모든 말풍선에 붙으므로 시간 간격으로 이름을 다시 띄울 이유가 없다 —
        // WorkChat과 같은 규칙(날짜 또는 발신자 변화만 본다).
        let rows = DevChatLayout.rows(for: [
            text(alice, date(day: 30, hour: 9)),
            text(alice, date(day: 30, hour: 20)),
        ], calendar: calendar)

        #expect(rows.map(\.showsSender) == [true, false])
    }

    @Test("날이 바뀌면 같은 사람이어도 이름을 다시 보여준다")
    func newDayShowsSenderAgain() {
        // 구분선 아래 첫 줄이 이름 없이 시작하면 누가 말하는지 모르는 채 새 날이 시작된다.
        let rows = DevChatLayout.rows(for: [
            text(alice, date(day: 29, hour: 23)),
            text(alice, date(day: 30, hour: 1)),
        ], calendar: calendar)

        #expect(rows.map(\.showsSender) == [true, true])
    }

    // MARK: 사진 앨범

    @Test("연속된 사진은 하나의 앨범으로 묶인다")
    func consecutivePhotosGroup() {
        let rows = DevChatLayout.rows(for: [
            photo(alice, date(day: 30, hour: 9)),
            photo(alice, date(day: 30, hour: 9, minute: 1)),
            photo(alice, date(day: 30, hour: 9, minute: 2)),
        ], calendar: calendar)

        #expect(rows.count == 1)
        if case .photoGroup(let group) = rows[0].content {
            #expect(group.count == 3)
        } else {
            Issue.record("앨범으로 묶이지 않았습니다")
        }
    }

    @Test("사진 한 장은 앨범으로 묶지 않는다")
    func singlePhotoStaysSingle() {
        // 앨범에는 컨텍스트 메뉴를 달지 않으므로, 1장을 앨범으로 만들면 그 사진에
        // 리액션·답장을 남길 수 없게 된다.
        let rows = DevChatLayout.rows(for: [photo(alice, date(day: 30))], calendar: calendar)

        #expect(rows.count == 1)
        if case .single = rows[0].content {} else {
            Issue.record("1장짜리가 앨범으로 묶였습니다")
        }
    }

    @Test("보낸 사람이 다른 사진은 따로 묶인다")
    func photosFromDifferentSendersSplit() {
        let rows = DevChatLayout.rows(for: [
            photo(alice, date(day: 30, hour: 9)),
            photo(alice, date(day: 30, hour: 9, minute: 1)),
            photo(bob, date(day: 30, hour: 9, minute: 2)),
            photo(bob, date(day: 30, hour: 9, minute: 3)),
        ], calendar: calendar)

        #expect(rows.count == 2)
    }

    @Test("5분을 넘겨 온 사진은 다른 앨범이다")
    func photosFarApartSplit() {
        let rows = DevChatLayout.rows(for: [
            photo(alice, date(day: 30, hour: 9)),
            photo(alice, date(day: 30, hour: 9, minute: 1)),
            photo(alice, date(day: 30, hour: 9, minute: 10)),
            photo(alice, date(day: 30, hour: 9, minute: 11)),
        ], calendar: calendar)

        #expect(rows.count == 2)
    }

    @Test("날이 다른 사진은 한 앨범으로 묶지 않는다 — 날짜 구분선이 사라지면 안 된다")
    func photosAcrossDaysSplit() {
        // 자정을 걸쳐 5분 안에 온 사진들. 시간만 보면 묶이지만 그러면 날짜 구분선이 사라진다.
        let rows = DevChatLayout.rows(for: [
            photo(alice, date(day: 29, hour: 23, minute: 59)),
            photo(alice, date(day: 30, hour: 0, minute: 1)),
        ], calendar: calendar)

        #expect(rows.count == 2)
        #expect(rows[1].dateSeparator != nil)
    }

    @Test("답장이 달린 사진은 앨범으로 묶지 않는다")
    func photoWithReplyStaysSingle() {
        // 앨범에는 답장 인용을 그릴 자리가 없다.
        let rows = DevChatLayout.rows(for: [
            photo(alice, date(day: 30, hour: 9)),
            photo(alice, date(day: 30, hour: 9, minute: 1), replyTo: UUID()),
        ], calendar: calendar)

        #expect(rows.count == 2)
    }

    @Test("지운 사진은 앨범으로 묶지 않는다")
    func deletedPhotoStaysSingle() {
        var deleted = photo(alice, date(day: 30, hour: 9, minute: 1))
        deleted.deletedAt = date(day: 30, hour: 10)

        let rows = DevChatLayout.rows(for: [
            photo(alice, date(day: 30, hour: 9)),
            deleted,
        ], calendar: calendar)

        #expect(rows.count == 2)
    }

    @Test("앨범 행의 시각은 마지막 사진 기준이다")
    func groupRowUsesLastTimestamp() {
        let last = date(day: 30, hour: 9, minute: 2)
        let rows = DevChatLayout.rows(for: [
            photo(alice, date(day: 30, hour: 9)),
            photo(alice, last),
        ], calendar: calendar)

        #expect(rows[0].last.createdAt == last)
    }

    @Test("행 id는 첫 메시지 id를 쓴다 — ForEach가 재사용할 수 있어야 한다")
    func rowIDIsFirstMessageID() {
        let first = photo(alice, date(day: 30, hour: 9))
        let rows = DevChatLayout.rows(for: [
            first,
            photo(alice, date(day: 30, hour: 9, minute: 1)),
        ], calendar: calendar)

        #expect(rows[0].id == first.id)
    }

    // MARK: 사진 그리드 행 구성

    @Test("사진 개수별 행 구성 — 마지막 줄에 한 장만 남기지 않는다")
    func photoRowPlan() {
        #expect(DevChatPhotoGrid.rowPlan(for: 4) == [2, 2])
        #expect(DevChatPhotoGrid.rowPlan(for: 5) == [3, 2])
        #expect(DevChatPhotoGrid.rowPlan(for: 6) == [3, 3])
        #expect(DevChatPhotoGrid.rowPlan(for: 7) == [3, 2, 2])
        #expect(DevChatPhotoGrid.rowPlan(for: 8) == [3, 3, 2])
        #expect(DevChatPhotoGrid.rowPlan(for: 9) == [3, 3, 3])
        #expect(DevChatPhotoGrid.rowPlan(for: 10) == [3, 3, 2, 2])
    }

    @Test("행 구성의 합은 항상 사진 개수와 같다")
    func rowPlanCoversEveryPhoto() {
        for count in 4...30 {
            let plan = DevChatPhotoGrid.rowPlan(for: count)
            #expect(plan.reduce(0, +) == count, "\(count)장의 행 구성이 \(plan)입니다")
            #expect(!plan.contains(1), "\(count)장에서 한 장만 남는 줄이 생겼습니다: \(plan)")
        }
    }

    // MARK: 리액션 묶기

    @Test("리액션을 이모지별로 묶고 내가 누른 것을 표시한다")
    func reactionGrouping() {
        let message = UUID()
        let me = UUID()
        let other = UUID()
        let summaries = [
            DevReaction(messageId: message, userId: me, emoji: "👍"),
            DevReaction(messageId: message, userId: other, emoji: "👍"),
            DevReaction(messageId: message, userId: other, emoji: "🎉"),
        ].groupedByMessage(myID: me)[message]

        #expect(summaries?.count == 2)
        // 개수가 많은 것이 먼저 온다.
        #expect(summaries?[0].emoji == "👍")
        #expect(summaries?[0].count == 2)
        #expect(summaries?[0].reactedByMe == true)
        #expect(summaries?[1].emoji == "🎉")
        #expect(summaries?[1].reactedByMe == false)
    }

    @Test("개수가 같으면 이모지 순서로 고정한다 — 알약 자리가 흔들리면 안 된다")
    func reactionOrderIsStable() {
        let message = UUID()
        let me = UUID()
        let first = [
            DevReaction(messageId: message, userId: me, emoji: "🔥"),
            DevReaction(messageId: message, userId: UUID(), emoji: "✅"),
        ].groupedByMessage(myID: me)[message]
        let reversed = [
            DevReaction(messageId: message, userId: UUID(), emoji: "✅"),
            DevReaction(messageId: message, userId: me, emoji: "🔥"),
        ].groupedByMessage(myID: me)[message]

        #expect(first?.map(\.emoji) == reversed?.map(\.emoji))
    }
}
#endif
