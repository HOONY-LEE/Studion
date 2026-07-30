#if DEBUG
import Foundation
import Testing
@testable import Studion

/// 대화 목록 시각 표기. 실제 시계에 의존하지 않도록 `now`를 고정해 경계를 검증한다.
@Suite("개발자 메신저 시각 표기")
struct DevChatTimestampTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        // 시간대가 바뀌면 "어제"의 경계도 바뀐다. 테스트는 한 시간대로 고정한다.
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    /// 2026년 7월 30일 (목) 15:00 KST를 "지금"으로 삼는다.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 30, hour: 15))!
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test("같은 날이면 시각만 보여준다")
    func todayShowsTime() {
        #expect(DevChatTimestamp.style(for: date(7, 30, 9), now: now, calendar: calendar) == .time)
    }

    @Test("같은 날 자정 직후도 오늘이다")
    func earlyTodayIsStillToday() {
        #expect(DevChatTimestamp.style(for: date(7, 30, 0), now: now, calendar: calendar) == .time)
    }

    @Test("하루 전은 어제다 — 흐른 시간이 24시간이 안 돼도 날짜로 판단한다")
    func yesterday() {
        // 어제 23시는 지금(오늘 15시)에서 16시간 전이지만 "어제"여야 한다.
        #expect(DevChatTimestamp.style(for: date(7, 29, 23), now: now, calendar: calendar) == .yesterday)
        // 어제 0시는 39시간 전이지만 역시 "어제"다.
        #expect(DevChatTimestamp.style(for: date(7, 29, 0), now: now, calendar: calendar) == .yesterday)
    }

    @Test("이틀 전부터는 날짜로 보여준다")
    func olderShowsDate() {
        #expect(DevChatTimestamp.style(for: date(7, 28), now: now, calendar: calendar) == .date)
        #expect(DevChatTimestamp.style(for: date(7, 23), now: now, calendar: calendar) == .date)
        #expect(DevChatTimestamp.style(for: date(1, 5), now: now, calendar: calendar) == .date)
    }

    @Test("미래 시각도 분류가 비지 않는다")
    func futureDatesStillClassify() {
        // 기기 시계가 어긋나 서버 시각이 미래로 보일 수 있다. 어떤 입력에도 답이 있어야 한다.
        #expect(DevChatTimestamp.style(for: date(8, 5), now: now, calendar: calendar) == .date)
    }

    @Test("어제는 번역된 문구로 보여준다")
    func yesterdayIsLocalized() {
        let korean = DevChatTimestamp.listLabel(
            for: date(7, 29), now: now, calendar: calendar, locale: Locale(identifier: "ko"))
        #expect(korean == "어제")

        let english = DevChatTimestamp.listLabel(
            for: date(7, 29), now: now, calendar: calendar, locale: Locale(identifier: "en"))
        #expect(english == "Yesterday")
    }

    @Test("오늘과 지난 날짜는 서로 다른 형식으로 나온다")
    func labelsDifferByStyle() {
        let locale = Locale(identifier: "ko")
        let today = DevChatTimestamp.listLabel(
            for: date(7, 30, 9), now: now, calendar: calendar, locale: locale)
        let older = DevChatTimestamp.listLabel(
            for: date(7, 20), now: now, calendar: calendar, locale: locale)

        #expect(!today.isEmpty)
        #expect(!older.isEmpty)
        #expect(today != older)
        #expect(!today.contains("어제"))
        #expect(!older.contains("어제"))
    }
}
#endif
