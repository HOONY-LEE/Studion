import Foundation
import Testing
@testable import Studion

/// 캘린더 일정을 날짜별로 가르는 규칙. EventKit 없이 값 타입으로만 검증한다.
@Suite("캘린더 일정 날짜 배치")
struct CalendarEventGroupingTests {

    private var cal: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    private func event(
        _ title: String, from start: Date, to end: Date, allDay: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: CalendarEvent.makeID(eventIdentifier: title, start: start),
            eventIdentifier: title,
            title: title,
            start: start,
            end: end,
            isAllDay: allDay,
            colorHex: nil,
            isEditable: true
        )
    }

    @Test("일정이 없으면 빈 결과다")
    func empty() {
        #expect(CalendarEventGrouping.eventsByDay([], calendar: cal).isEmpty)
    }

    @Test("하루짜리 일정은 그날에만 들어간다")
    func singleDay() {
        let grouped = CalendarEventGrouping.eventsByDay(
            [event("회의", from: date(15, 10), to: date(15, 11))], calendar: cal)

        #expect(grouped[date(15)]?.count == 1)
        #expect(grouped[date(14)] == nil)
        #expect(grouped[date(16)] == nil)
    }

    @Test("여러 날에 걸친 일정은 사이의 모든 날에 들어간다")
    func multiDaySpansEveryDay() {
        // 시작일만 보고 넣으면 중간 날짜에서 사라진다.
        let grouped = CalendarEventGrouping.eventsByDay(
            [event("여행", from: date(15, 9), to: date(18, 20))], calendar: cal)

        for day in 15...18 {
            #expect(grouped[date(day)]?.count == 1, "7월 \(day)일에 없습니다")
        }
        #expect(grouped[date(14)] == nil)
        #expect(grouped[date(19)] == nil)
    }

    @Test("자정에 끝나는 일정은 전날까지만 걸친다")
    func midnightEndDoesNotSpillOver() {
        // 17일 0시에 끝나는 일정은 실제로는 16일까지다. 그러지 않으면 달력에 하루 더 보인다.
        let grouped = CalendarEventGrouping.eventsByDay(
            [event("합숙", from: date(15, 9), to: date(17, 0))], calendar: cal)

        #expect(grouped[date(15)]?.count == 1)
        #expect(grouped[date(16)]?.count == 1)
        #expect(grouped[date(17)] == nil)
    }

    @Test("자정 직후에 끝나면 그날까지 걸친다 — 0시 규칙이 과하게 적용되면 안 된다")
    func justAfterMidnightStillCounts() {
        let grouped = CalendarEventGrouping.eventsByDay(
            [event("야간작업", from: date(15, 22), to: date(16, 0, 30))], calendar: cal)

        #expect(grouped[date(16)]?.count == 1)
    }

    @Test("하루짜리 종일 일정은 그날에만 들어간다")
    func singleAllDay() {
        // 종일 일정의 종료는 다음 날 0시로 표현된다 — 그대로 세면 이틀이 된다.
        let grouped = CalendarEventGrouping.eventsByDay(
            [event("개교기념일", from: date(15), to: date(16), allDay: true)], calendar: cal)

        #expect(grouped[date(15)]?.count == 1)
        #expect(grouped[date(16)] == nil)
    }

    @Test("여러 날 종일 일정은 마지막 날까지 들어간다")
    func multiDayAllDay() {
        let grouped = CalendarEventGrouping.eventsByDay(
            [event("방학", from: date(15), to: date(18), allDay: true)], calendar: cal)

        for day in 15...17 {
            #expect(grouped[date(day)]?.count == 1, "7월 \(day)일에 없습니다")
        }
        #expect(grouped[date(18)] == nil)
    }

    @Test("종일 일정이 시각 일정보다 위에 온다")
    func allDaySortsFirst() {
        let grouped = CalendarEventGrouping.eventsByDay([
            event("아침 회의", from: date(15, 9), to: date(15, 10)),
            event("체육대회", from: date(15), to: date(16), allDay: true),
        ], calendar: cal)

        #expect(grouped[date(15)]?.first?.title == "체육대회")
    }

    @Test("같은 날 일정은 시작 시각 순으로 정렬된다")
    func sortedByStart() {
        let grouped = CalendarEventGrouping.eventsByDay([
            event("저녁", from: date(15, 18), to: date(15, 19)),
            event("아침", from: date(15, 8), to: date(15, 9)),
            event("점심", from: date(15, 12), to: date(15, 13)),
        ], calendar: cal)

        #expect(grouped[date(15)]?.map(\.title) == ["아침", "점심", "저녁"])
    }

    @Test("시작 시각이 같으면 제목 순으로 고정한다 — 다시 그릴 때 순서가 흔들리면 안 된다")
    func stableOrderForSameStart() {
        let first = CalendarEventGrouping.eventsByDay([
            event("나중", from: date(15, 9), to: date(15, 10)),
            event("가나다", from: date(15, 9), to: date(15, 10)),
        ], calendar: cal)
        let reversed = CalendarEventGrouping.eventsByDay([
            event("가나다", from: date(15, 9), to: date(15, 10)),
            event("나중", from: date(15, 9), to: date(15, 10)),
        ], calendar: cal)

        #expect(first[date(15)]?.map(\.title) == reversed[date(15)]?.map(\.title))
    }

    @Test("종료가 시작보다 빨라도 그날에는 들어간다 — 어긋난 데이터로 사라지면 안 된다")
    func invalidRangeStillAppears() {
        let grouped = CalendarEventGrouping.eventsByDay(
            [event("잘못된 일정", from: date(15, 10), to: date(14, 9))], calendar: cal)

        #expect(grouped[date(15)]?.count == 1)
    }

    @Test("반복 일정의 각 발생은 서로 다른 id를 갖는다")
    func recurringOccurrencesHaveDistinctIDs() {
        // eventIdentifier만 쓰면 같은 주의 반복 일정이 한 칸으로 합쳐진다.
        let monday = CalendarEvent.makeID(eventIdentifier: "weekly", start: date(13, 9))
        let tuesday = CalendarEvent.makeID(eventIdentifier: "weekly", start: date(14, 9))
        #expect(monday != tuesday)
    }
}
