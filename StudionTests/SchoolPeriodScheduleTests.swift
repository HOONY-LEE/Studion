import Testing
@testable import Studion

/// 학교 일과표. 시간표 화면이 어느 줄에 무엇을 그릴지 여기서 정한다.
///
/// 학교마다 다르므로 사용자가 고칠 수 있는데, **고친 값이 이상해도 표는 그려져야 한다** —
/// 시간표는 앱을 여는 순간 보여야 하는 화면이라 실패를 사용자에게 떠넘길 수 없다.
@Suite("학교 일과표")
struct SchoolPeriodScheduleTests {

    // MARK: 표준 일과

    @Test("표준 일과는 흔히 쓰는 시각 그대로다")
    func standardMatchesCommonSchedule() {
        // 08:40 1교시 시작, 50분 수업, 10분 쉬는 시간, 4교시 뒤 50분 점심.
        let periods = SchoolPeriodSchedule.standard.periods
        #expect(periods.map(\.startMinutes) == [
            8 * 60 + 40,   // 1교시
            9 * 60 + 40,   // 2교시
            10 * 60 + 40,  // 3교시
            11 * 60 + 40,  // 4교시
            13 * 60 + 20,  // 5교시 — 점심 뒤
            14 * 60 + 20,  // 6교시
            15 * 60 + 20,  // 7교시
        ])
        #expect(periods.allSatisfy { $0.endMinutes - $0.startMinutes == 50 })
    }

    @Test("교시는 1번부터 빠짐없이 이어진다")
    func numbersAreSequential() {
        let schedule = SchoolPeriodSchedule.standard
        #expect(schedule.periods.map(\.number) == Array(1...schedule.periodCount))
    }

    @Test("교시는 시작보다 끝이 늦고, 서로 겹치지 않는다")
    func periodsDoNotOverlap() {
        // 겹치면 한 시간대가 두 줄에 그려진다.
        var previousEnd = 0
        for period in SchoolPeriodSchedule.standard.periods {
            #expect(period.startMinutes < period.endMinutes)
            #expect(period.startMinutes >= previousEnd)
            previousEnd = period.endMinutes
        }
    }

    // MARK: 학교에 맞게 고치기

    @Test("1교시 시작을 바꾸면 이후 교시가 통째로 밀린다")
    func shiftingFirstPeriodMovesEverything() {
        // 실제로 사용자가 가장 자주 고치는 값이다 — 학교마다 조회 시각이 다르다.
        var schedule = SchoolPeriodSchedule.standard
        schedule.firstPeriodStartMinutes = 9 * 60  // 09:00 시작

        let periods = schedule.periods
        #expect(periods[0].startMinutes == 9 * 60)
        #expect(periods[1].startMinutes == 10 * 60)      // 09:50 끝 + 10분
        #expect(periods[4].startMinutes == 13 * 60 + 40) // 점심 뒤 5교시도 같이 밀린다
    }

    @Test("수업 길이를 바꾸면 간격이 함께 바뀐다")
    func lessonLengthChangesSpacing() {
        var schedule = SchoolPeriodSchedule.standard
        schedule.lessonMinutes = 45

        let periods = schedule.periods
        #expect(periods[0].endMinutes == 8 * 60 + 40 + 45)
        #expect(periods[1].startMinutes == 8 * 60 + 40 + 45 + 10)
    }

    @Test("점심이 낀 교시 뒤에만 점심시간이 들어간다")
    func lunchOnlyAfterItsPeriod() {
        let schedule = SchoolPeriodSchedule.standard
        let periods = schedule.periods

        let afterFourth = periods[4].startMinutes - periods[3].endMinutes
        let afterFifth = periods[5].startMinutes - periods[4].endMinutes
        #expect(afterFourth == schedule.lunchMinutes)
        #expect(afterFifth == schedule.breakMinutes)
    }

    @Test("점심이 몇 교시 뒤인지도 바꿀 수 있다")
    func lunchPositionIsConfigurable() {
        var schedule = SchoolPeriodSchedule.standard
        schedule.lunchAfterPeriod = 5

        let periods = schedule.periods
        #expect(periods[5].startMinutes - periods[4].endMinutes == schedule.lunchMinutes)
        #expect(periods[4].startMinutes - periods[3].endMinutes == schedule.breakMinutes)
    }

    @Test("점심 없는 일과도 만들 수 있다")
    func scheduleWithoutLunch() {
        var schedule = SchoolPeriodSchedule.standard
        schedule.lunchAfterPeriod = 0

        let periods = schedule.periods
        for index in 1..<periods.count {
            #expect(periods[index].startMinutes - periods[index - 1].endMinutes == schedule.breakMinutes)
        }
        #expect(!periods.contains(where: schedule.isBeforeLunch))
    }

    @Test("점심 구분선은 점심 직전 교시에만 붙는다")
    func lunchMarkOnlyBeforeLunch() {
        let schedule = SchoolPeriodSchedule.standard
        let beforeLunch = schedule.periods.filter(schedule.isBeforeLunch)
        #expect(beforeLunch.map(\.number) == [4])
    }

    @Test("마지막 교시 뒤에는 점심 구분선을 긋지 않는다")
    func noLunchMarkAtTheEnd() {
        // 4교시까지만 보는 사람에게 표 맨 아래 굵은 선이 걸리면 잘린 것처럼 보인다.
        var schedule = SchoolPeriodSchedule.standard
        schedule.periodCount = 4

        #expect(!schedule.periods.contains(where: schedule.isBeforeLunch))
    }

    // MARK: 이상한 값이 들어와도 버틴다

    @Test("범위를 벗어난 설정은 안쪽으로 당긴다")
    func outOfRangeValuesAreClamped() {
        let broken = SchoolPeriodSchedule(
            firstPeriodStartMinutes: -100,
            lessonMinutes: 0,
            breakMinutes: -5,
            lunchAfterPeriod: 99,
            lunchMinutes: 9999,
            periodCount: 99
        )
        let safe = broken.sanitized

        #expect(safe.firstPeriodStartMinutes >= 0)
        #expect(SchoolPeriodSchedule.lessonMinutesRange.contains(safe.lessonMinutes))
        #expect(SchoolPeriodSchedule.breakMinutesRange.contains(safe.breakMinutes))
        #expect(SchoolPeriodSchedule.lunchMinutesRange.contains(safe.lunchMinutes))
        #expect(SchoolPeriodSchedule.periodCountRange.contains(safe.periodCount))
        #expect(safe.lunchAfterPeriod <= safe.periodCount)
        // 그리고 무엇보다 표가 그려져야 한다.
        #expect(!broken.periods.isEmpty)
    }

    // MARK: 저장/복원

    @Test("저장했다 되살리면 그대로다")
    func jsonRoundTrips() {
        var schedule = SchoolPeriodSchedule.standard
        schedule.firstPeriodStartMinutes = 9 * 60 + 10
        schedule.periodCount = 8

        #expect(SchoolPeriodSchedule(json: schedule.json) == schedule)
    }

    @Test("저장된 값이 없거나 깨졌으면 표준 일과로 돌아간다")
    func brokenJsonFallsBackToStandard() {
        // 시간표는 앱을 여는 순간 보여야 한다 — 복원 실패로 빈 화면을 띄우지 않는다.
        #expect(SchoolPeriodSchedule(json: "") == .standard)
        #expect(SchoolPeriodSchedule(json: "{{{ 망가진 값") == .standard)
    }

    // MARK: 겹치는 교시 찾기

    @Test("한 교시에 딱 맞는 일정은 그 교시만 차지한다")
    func exactMatchOccupiesOnePeriod() {
        let schedule = SchoolPeriodSchedule.standard
        let third = schedule.period(number: 3)!
        let found = schedule.periods(overlapping: third.startMinutes, end: third.endMinutes)
        #expect(found.map(\.number) == [3])
    }

    @Test("두 교시에 걸친 블록 수업은 두 줄을 차지한다")
    func blockLessonSpansTwoPeriods() {
        let schedule = SchoolPeriodSchedule.standard
        let first = schedule.period(number: 1)!
        let second = schedule.period(number: 2)!
        let found = schedule.periods(overlapping: first.startMinutes, end: second.endMinutes)
        #expect(found.map(\.number) == [1, 2])
    }

    @Test("쉬는 시간에만 걸친 일정은 어느 교시도 차지하지 않는다")
    func breakTimeOccupiesNothing() {
        let schedule = SchoolPeriodSchedule.standard
        let first = schedule.period(number: 1)!
        let second = schedule.period(number: 2)!
        let found = schedule.periods(overlapping: first.endMinutes, end: second.startMinutes)
        #expect(found.isEmpty)
    }

    @Test("일과 뒤 학원 일정은 표에 걸리지 않는다")
    func afterSchoolFallsOutsideGrid() {
        // 표에 안 걸리는 일정은 화면에서 따로 보여줘야 한다 — 사라지면 안 된다.
        let found = SchoolPeriodSchedule.standard.periods(overlapping: 21 * 60, end: 22 * 60)
        #expect(found.isEmpty)
    }

    @Test("보여주는 교시 수를 넘어가면 걸리지 않는다")
    func beyondVisiblePeriodsIsExcluded() {
        var eight = SchoolPeriodSchedule.standard
        eight.periodCount = 8
        let eighth = eight.period(number: 8)!

        let sevenPeriods = SchoolPeriodSchedule.standard
        #expect(sevenPeriods.periods(overlapping: eighth.startMinutes, end: eighth.endMinutes).isEmpty)
        #expect(eight.periods(overlapping: eighth.startMinutes, end: eighth.endMinutes).map(\.number) == [8])
    }

    @Test("경계 시각은 다음 교시에 붙지 않는다")
    func boundaryDoesNotBleed() {
        let first = SchoolPeriodSchedule.standard.period(number: 1)!
        #expect(first.contains(minutes: first.startMinutes))
        #expect(!first.contains(minutes: first.endMinutes))
    }
}
