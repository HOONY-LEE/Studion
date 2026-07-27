import Foundation
import Testing
@testable import Studion

/// 타임존을 고정하지 않으면 이 테스트는 CI에서 무의미해진다.
private let cal: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    calendar.locale = Locale(identifier: "ko_KR")
    return calendar
}()

private func makeDate(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0
) -> Date {
    cal.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute
    ))!
}

// MARK: - 하루 단위 비교

@Suite("하루 단위 비교")
struct SameDayTests {

    @Test("같은 날의 00:00과 23:59는 같은 날이다")
    func sameDayAcrossHours() {
        let midnight = makeDate(2026, 3, 10, 0, 0)
        let almostMidnight = makeDate(2026, 3, 10, 23, 59)
        #expect(PlannerDateHelper.isSameDay(midnight, almostMidnight, calendar: cal))
    }

    @Test("자정 직전과 직후는 다른 날이다")
    func acrossMidnight() {
        let before = makeDate(2026, 3, 10, 23, 59)
        let after = makeDate(2026, 3, 11, 0, 0)
        #expect(!PlannerDateHelper.isSameDay(before, after, calendar: cal))
    }

    @Test("startOfDay는 시각을 0으로 만든다")
    func startOfDayNormalizes() {
        let result = PlannerDateHelper.startOfDay(makeDate(2026, 3, 10, 15, 42), calendar: cal)
        #expect(result == makeDate(2026, 3, 10, 0, 0))
    }
}

// MARK: - 요일 변환

@Suite("요일 변환")
struct WeekdayConversionTests {

    @Test("Calendar 컨벤션 → 표시 인덱스", arguments: [
        (1, 6),  // 일요일 → 마지막
        (2, 0),  // 월요일 → 처음
        (7, 5),  // 토요일
    ])
    func toDisplayIndex(weekday: Int, expected: Int) {
        #expect(PlannerDateHelper.displayIndex(forCalendarWeekday: weekday) == expected)
    }

    @Test("1...7 전 범위에서 왕복 항등")
    func roundTripIdentity() {
        for weekday in 1...7 {
            let index = PlannerDateHelper.displayIndex(forCalendarWeekday: weekday)
            #expect(PlannerDateHelper.calendarWeekday(forDisplayIndex: index) == weekday)
            #expect((0...6).contains(index))
        }
    }

    @Test("표시 인덱스 0...6도 왕복 항등")
    func reverseRoundTrip() {
        for index in 0...6 {
            let weekday = PlannerDateHelper.calendarWeekday(forDisplayIndex: index)
            #expect(PlannerDateHelper.displayIndex(forCalendarWeekday: weekday) == index)
            #expect((1...7).contains(weekday))
        }
    }
}

// MARK: - 주 단위

@Suite("주 단위")
struct WeekDatesTests {

    @Test("결과는 월요일 시작 7일이고 정규화·오름차순이다")
    func weekShape() {
        // 2026-03-11은 수요일
        let dates = PlannerDateHelper.weekDates(containing: makeDate(2026, 3, 11), calendar: cal)
        #expect(dates.count == 7)
        #expect(PlannerDateHelper.calendarWeekday(of: dates[0], calendar: cal) == 2)  // 월요일
        #expect(dates == dates.sorted())
        for date in dates {
            #expect(date == PlannerDateHelper.startOfDay(date, calendar: cal))
        }
    }

    @Test("일요일을 넣으면 그 주의 월요일이 나온다 — 가장 틀리기 쉬운 케이스")
    func sundayBelongsToPrecedingMonday() {
        // 2026-03-15는 일요일. 그 주 월요일은 2026-03-09
        let sunday = makeDate(2026, 3, 15)
        #expect(PlannerDateHelper.calendarWeekday(of: sunday, calendar: cal) == 1)

        let dates = PlannerDateHelper.weekDates(containing: sunday, calendar: cal)
        #expect(dates[0] == makeDate(2026, 3, 9))
        #expect(dates[6] == sunday)
    }

    @Test("월요일을 넣으면 그 날이 첫 원소다")
    func mondayIsFirst() {
        let monday = makeDate(2026, 3, 9)
        let dates = PlannerDateHelper.weekDates(containing: monday, calendar: cal)
        #expect(dates[0] == monday)
    }
}

// MARK: - 월 그리드

@Suite("월 그리드")
struct MonthGridTests {

    @Test("길이가 7의 배수이고 월요일로 시작한다")
    func gridShape() {
        let dates = PlannerDateHelper.monthGridDates(for: makeDate(2026, 3, 10), calendar: cal)
        #expect(dates.count % 7 == 0)
        #expect(PlannerDateHelper.calendarWeekday(of: dates[0], calendar: cal) == 2)
    }

    @Test("해당 월의 1일과 말일을 모두 포함한다")
    func containsMonthBounds() {
        let dates = PlannerDateHelper.monthGridDates(for: makeDate(2026, 3, 10), calendar: cal)
        #expect(dates.contains(makeDate(2026, 3, 1)))
        #expect(dates.contains(makeDate(2026, 3, 31)))
    }

    @Test("1일이 일요일인 달 — 2026년 2월")
    func monthStartingOnSunday() {
        #expect(PlannerDateHelper.calendarWeekday(of: makeDate(2026, 2, 1), calendar: cal) == 1)

        let dates = PlannerDateHelper.monthGridDates(for: makeDate(2026, 2, 15), calendar: cal)
        #expect(dates.count % 7 == 0)
        #expect(dates.contains(makeDate(2026, 2, 1)))
        #expect(dates.contains(makeDate(2026, 2, 28)))
        // 1일이 일요일이면 그리드는 앞 주 월요일(1월 26일)부터 시작한다.
        #expect(dates[0] == makeDate(2026, 1, 26))
    }

    @Test("말일이 월요일인 달 — 2026년 8월")
    func monthEndingOnMonday() {
        #expect(PlannerDateHelper.calendarWeekday(of: makeDate(2026, 8, 31), calendar: cal) == 2)

        let dates = PlannerDateHelper.monthGridDates(for: makeDate(2026, 8, 10), calendar: cal)
        #expect(dates.count % 7 == 0)
        #expect(dates.contains(makeDate(2026, 8, 31)))
        // 말일이 월요일이면 그 주 일요일(9월 6일)까지 채워진다.
        #expect(dates.last == makeDate(2026, 9, 6))
    }
}

// MARK: - 시각

@Suite("시각 (날짜 무시)")
struct TimeOfDayTests {

    @Test("09:30은 570분이다")
    func minutesConversion() {
        #expect(PlannerDateHelper.minutesOfDay(makeDate(2026, 3, 10, 9, 30), calendar: cal) == 570)
    }

    @Test("날짜가 달라도 시·분이 같으면 같은 값이다")
    func dateIndependent() {
        let a = PlannerDateHelper.minutesOfDay(makeDate(2026, 3, 10, 9, 30), calendar: cal)
        let b = PlannerDateHelper.minutesOfDay(makeDate(2030, 12, 25, 9, 30), calendar: cal)
        #expect(a == b)
    }

    @Test("유효한 시간 구간 판정", arguments: [
        (9, 0, 10, 0, true),
        (10, 0, 10, 0, false),
        (10, 0, 9, 0, false),
        (0, 0, 23, 59, true),
    ])
    func validRange(sh: Int, sm: Int, eh: Int, em: Int, expected: Bool) {
        let start = makeDate(2026, 3, 10, sh, sm)
        let end = makeDate(2026, 3, 10, eh, em)
        #expect(PlannerDateHelper.isValidTimeRange(start: start, end: end, calendar: cal) == expected)
    }

    @Test("날짜가 서로 달라도 시·분만으로 판정한다")
    func rangeIgnoresDateComponent() {
        // 종료가 며칠 뒤 Date여도 시각이 이르면 유효하지 않다 (자정 넘김 미지원)
        let start = makeDate(2026, 3, 10, 22, 0)
        let end = makeDate(2026, 3, 12, 2, 0)
        #expect(!PlannerDateHelper.isValidTimeRange(start: start, end: end, calendar: cal))
    }
}

// MARK: - 일 단위 이동

@Suite("일 단위 이동")
struct AddingDaysTests {

    @Test("앞뒤 이동과 0 이동")
    func basicMoves() {
        let base = makeDate(2026, 3, 10)
        #expect(PlannerDateHelper.addingDays(1, to: base, calendar: cal) == makeDate(2026, 3, 11))
        #expect(PlannerDateHelper.addingDays(-1, to: base, calendar: cal) == makeDate(2026, 3, 9))
        #expect(PlannerDateHelper.addingDays(0, to: base, calendar: cal) == base)
    }

    @Test("월말을 넘긴다")
    func acrossMonthEnd() {
        #expect(
            PlannerDateHelper.addingDays(1, to: makeDate(2026, 3, 31), calendar: cal)
                == makeDate(2026, 4, 1)
        )
    }

    @Test("연말을 넘긴다")
    func acrossYearEnd() {
        #expect(
            PlannerDateHelper.addingDays(1, to: makeDate(2026, 12, 31), calendar: cal)
                == makeDate(2027, 1, 1)
        )
    }

    @Test("시각이 있는 날짜를 넣어도 결과가 정규화된다")
    func resultIsNormalized() {
        let result = PlannerDateHelper.addingDays(1, to: makeDate(2026, 3, 10, 17, 45), calendar: cal)
        #expect(result == makeDate(2026, 3, 11, 0, 0))
    }
}

// MARK: - 겹침 배치

@Suite("겹침 배치")
struct LayoutTests {

    private func range(_ start: Int, _ end: Int) -> PlannerDateHelper.TimeRange {
        .init(id: UUID(), startMinutes: start, endMinutes: end)
    }

    @Test("겹치지 않으면 전부 컬럼 0, 컬럼 수 1")
    func noOverlap() {
        let ranges = [range(540, 600), range(660, 720), range(780, 840)]
        let result = PlannerDateHelper.layout(ranges)
        #expect(result.count == 3)
        #expect(result.allSatisfy { $0.column == 0 && $0.columnCount == 1 })
    }

    @Test("2개가 겹치면 컬럼 0과 1로 나뉜다")
    func twoOverlapping() {
        let a = range(540, 660)
        let b = range(600, 720)
        let result = PlannerDateHelper.layout([a, b])
        #expect(result.allSatisfy { $0.columnCount == 2 })
        #expect(Set(result.map(\.column)) == [0, 1])
    }

    @Test("3개가 겹치면 컬럼 수가 3이다")
    func threeOverlapping() {
        let ranges = [range(540, 720), range(560, 700), range(580, 680)]
        let result = PlannerDateHelper.layout(ranges)
        #expect(result.allSatisfy { $0.columnCount == 3 })
        #expect(Set(result.map(\.column)) == [0, 1, 2])
    }

    @Test("경계 접촉은 겹침이 아니다")
    func touchingBoundaryIsNotOverlap() {
        let result = PlannerDateHelper.layout([range(600, 660), range(660, 720)])
        #expect(result.allSatisfy { $0.column == 0 && $0.columnCount == 1 })
    }

    @Test("빈 입력은 빈 결과")
    func emptyInput() {
        #expect(PlannerDateHelper.layout([]).isEmpty)
    }

    @Test("떨어진 두 겹침 그룹은 서로 독립적으로 계산된다")
    func independentGroups() {
        let a1 = range(540, 660), a2 = range(600, 700)   // 그룹 1: 2열
        let b1 = range(800, 900)                          // 그룹 2: 1열
        let result = PlannerDateHelper.layout([a1, a2, b1])

        let group1 = result.filter { $0.id == a1.id || $0.id == a2.id }
        let group2 = result.filter { $0.id == b1.id }
        #expect(group1.allSatisfy { $0.columnCount == 2 })
        #expect(group2.allSatisfy { $0.columnCount == 1 })
    }
}

// MARK: - 완료율 농도

@Suite("완료율 농도")
struct HeatLevelTests {

    @Test("완료율 → 단계", arguments: [
        (0, 0, 0),    // 데이터 없음 → 테두리만
        (0, 4, 1),    // 0%
        (1, 4, 2),    // 25%
        (2, 4, 3),    // 50%
        (3, 4, 4),    // 75%
        (4, 4, 5),    // 100%
    ])
    func levels(completed: Int, total: Int, expected: Int) {
        #expect(PlannerDateHelper.heatLevel(completed: completed, total: total) == expected)
    }

    @Test("completed가 total을 넘어도 클램프된다")
    func clampsOverflow() {
        #expect(PlannerDateHelper.heatLevel(completed: 10, total: 4) == 5)
    }

    @Test("음수 completed도 크래시 없이 처리된다")
    func clampsNegative() {
        #expect(PlannerDateHelper.heatLevel(completed: -3, total: 4) == 1)
    }

    @Test("total이 음수면 0이다")
    func negativeTotal() {
        #expect(PlannerDateHelper.heatLevel(completed: 1, total: -1) == 0)
    }
}
