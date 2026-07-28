import Foundation
import Testing
@testable import Studion

/// `docs/03-domain-logic.md` §3의 테스트 벡터를 그대로 옮긴 것이다.
private let cal: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    calendar.locale = Locale(identifier: "ko_KR")
    return calendar
}()

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int = 0) -> Date {
    cal.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: hour))!
}

/// 기준일 2026-03-10
private let base = day(2026, 3, 10)

@Suite("복습 스케줄 — 맞음")
struct CorrectOutcomeTests {

    @Test("박스가 한 칸 오르고 해당 간격만큼 밀린다", arguments: [
        (0, 1, 3),    // 0 → 1, +3일
        (1, 2, 7),    // 1 → 2, +7일
        (3, 4, 30),   // 3 → 4, +30일
    ])
    func advances(currentBox: Int, expectedBox: Int, expectedDays: Int) {
        let result = ReviewScheduler.nextSchedule(
            currentBox: currentBox, outcome: .correct, reviewedAt: base, calendar: cal
        )
        #expect(result.boxIndex == expectedBox)
        #expect(result.nextReviewDate == cal.date(byAdding: .day, value: expectedDays, to: base)!)
    }

    @Test("최상위 박스에서는 상한을 유지한다")
    func staysAtMaximum() {
        let result = ReviewScheduler.nextSchedule(
            currentBox: 4, outcome: .correct, reviewedAt: base, calendar: cal
        )
        #expect(result.boxIndex == 4)
        #expect(result.nextReviewDate == day(2026, 4, 9))  // +30일
    }
}

@Suite("복습 스케줄 — 틀림")
struct IncorrectOutcomeTests {

    @Test("어느 박스에서든 0으로 돌아가고 다음 날 복습한다", arguments: [0, 2, 4])
    func resetsToZero(currentBox: Int) {
        let result = ReviewScheduler.nextSchedule(
            currentBox: currentBox, outcome: .incorrect, reviewedAt: base, calendar: cal
        )
        #expect(result.boxIndex == 0)
        #expect(result.nextReviewDate == day(2026, 3, 11))  // +1일
    }
}

@Suite("복습 스케줄 — 범위 밖 입력")
struct ClampingTests {

    @Test("상한을 넘는 박스는 클램프된다")
    func clampsAbove() {
        let result = ReviewScheduler.nextSchedule(
            currentBox: 99, outcome: .correct, reviewedAt: base, calendar: cal
        )
        #expect(result.boxIndex == 4)
        #expect(result.nextReviewDate == day(2026, 4, 9))
    }

    @Test("음수 박스는 0으로 클램프된다")
    func clampsBelow() {
        let result = ReviewScheduler.nextSchedule(
            currentBox: -1, outcome: .correct, reviewedAt: base, calendar: cal
        )
        #expect(result.boxIndex == 1)
        #expect(result.nextReviewDate == day(2026, 3, 13))  // +3일
    }
}

@Suite("신규 카드")
struct InitialScheduleTests {

    @Test("box 0에서 시작하고 생성 다음 날부터 복습 대상이다")
    func startsNextDay() {
        let result = ReviewScheduler.initialSchedule(createdAt: base, calendar: cal)
        #expect(result.boxIndex == 0)
        #expect(result.nextReviewDate == day(2026, 3, 11))
    }

    @Test("생성 시각이 늦어도 날짜만 본다")
    func ignoresTimeOfDay() {
        let lateNight = ReviewScheduler.initialSchedule(createdAt: day(2026, 3, 10, 23), calendar: cal)
        let earlyMorning = ReviewScheduler.initialSchedule(createdAt: day(2026, 3, 10, 1), calendar: cal)
        #expect(lateNight == earlyMorning)
    }
}

@Suite("복습 대상 판정")
struct IsDueTests {

    @Test("복습일 당일이면 due다")
    func dueToday() {
        #expect(ReviewScheduler.isDue(nextReviewDate: base, on: base, calendar: cal))
    }

    @Test("복습일 하루 전이면 due가 아니다")
    func notYetDue() {
        #expect(!ReviewScheduler.isDue(nextReviewDate: base, on: day(2026, 3, 9), calendar: cal))
    }

    @Test("복습일이 지나도 계속 due로 남는다 — 밀린 복습이 사라지지 않게")
    func overdueStaysDue() {
        #expect(ReviewScheduler.isDue(nextReviewDate: base, on: day(2026, 3, 25), calendar: cal))
    }

    @Test("시각과 무관하게 날짜로만 판정한다")
    func ignoresTimeOfDay() {
        // 복습일 당일 새벽에도, 늦은 밤에도 동일하게 due
        #expect(ReviewScheduler.isDue(nextReviewDate: day(2026, 3, 10, 23), on: day(2026, 3, 10, 1), calendar: cal))
    }
}

@Suite("간격 정의")
struct IntervalTests {

    @Test("간격은 1, 3, 7, 14, 30일이다")
    func intervalsAreAsSpecified() {
        #expect(ReviewScheduler.intervals == [1, 3, 7, 14, 30])
        #expect(ReviewScheduler.maxBoxIndex == 4)
    }

    @Test("연속으로 맞히면 간격이 점점 길어진다")
    func intervalsGrowMonotonically() {
        var box = 0
        var previousGap = 0
        var reviewDate = base

        for _ in 0..<5 {
            let result = ReviewScheduler.nextSchedule(
                currentBox: box, outcome: .correct, reviewedAt: reviewDate, calendar: cal
            )
            let gap = cal.dateComponents([.day], from: reviewDate, to: result.nextReviewDate).day ?? 0
            #expect(gap >= previousGap)
            previousGap = gap
            box = result.boxIndex
            reviewDate = result.nextReviewDate
        }
    }
}
