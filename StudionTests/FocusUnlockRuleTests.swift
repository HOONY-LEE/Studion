import Foundation
import Testing
@testable import Studion

/// 집중 모드 해제 규칙. 이 규칙이 틀리면 학생 폰이 부당하게 잠기므로 경계를 촘촘히 못박는다.
/// 규칙 출처: `docs/09-app-shield.md` §2-2.
@Suite("집중 모드 해제 규칙")
struct FocusUnlockRuleTests {

    // MARK: 잠기면 안 되는 경우

    @Test("오늘 할 일이 없으면 차단하지 않는다")
    func noTasksNeverShields() {
        // 할 일을 안 만든 것이 폰이 잠길 이유가 되면 안 된다.
        let outcome = FocusUnlockRule.evaluate(
            completed: 0, total: 0, requiredRate: 0.8, alreadyUnlockedToday: false)
        #expect(outcome == .unlocked(.noTasksToday))
    }

    @Test("할 일이 없으면 목표가 100%여도 차단하지 않는다")
    func noTasksBeatsStrictGoal() {
        let outcome = FocusUnlockRule.evaluate(
            completed: 0, total: 0, requiredRate: 1.0, alreadyUnlockedToday: false)
        #expect(outcome == .unlocked(.noTasksToday))
    }

    @Test("한 번 풀리면 그날은 다시 잠기지 않는다")
    func onceUnlockedStaysUnlocked() {
        // 할 일을 지워 완료율이 떨어져도 마찬가지다 — 해제를 되돌리면 앱을 신뢰할 수 없게 된다.
        let outcome = FocusUnlockRule.evaluate(
            completed: 0, total: 10, requiredRate: 0.8, alreadyUnlockedToday: true)
        #expect(outcome == .unlocked(.alreadyUnlockedToday))
    }

    // MARK: 목표 판정

    @Test("목표를 채우면 풀린다")
    func reachingGoalUnlocks() {
        let outcome = FocusUnlockRule.evaluate(
            completed: 8, total: 10, requiredRate: 0.8, alreadyUnlockedToday: false)
        #expect(outcome == .unlocked(.goalReached))
    }

    @Test("목표에 못 미치면 차단한다")
    func belowGoalShields() {
        let outcome = FocusUnlockRule.evaluate(
            completed: 7, total: 10, requiredRate: 0.8, alreadyUnlockedToday: false)
        #expect(outcome == .shield)
    }

    @Test("경계값은 달성으로 본다 — 딱 맞췄는데 안 풀리면 억울하다")
    func exactBoundaryCounts() {
        // 4/5 = 0.8. 부동소수 비교로 미끄러지면 안 된다.
        #expect(FocusUnlockRule.evaluate(
            completed: 4, total: 5, requiredRate: 0.8, alreadyUnlockedToday: false)
                == .unlocked(.goalReached))
        #expect(FocusUnlockRule.evaluate(
            completed: 1, total: 2, requiredRate: 0.5, alreadyUnlockedToday: false)
                == .unlocked(.goalReached))
    }

    @Test("100% 목표는 전부 끝내야 풀린다")
    func fullGoalNeedsEverything() {
        #expect(FocusUnlockRule.evaluate(
            completed: 9, total: 10, requiredRate: 1.0, alreadyUnlockedToday: false) == .shield)
        #expect(FocusUnlockRule.evaluate(
            completed: 10, total: 10, requiredRate: 1.0, alreadyUnlockedToday: false)
                == .unlocked(.goalReached))
    }

    @Test("하나도 못 했으면 차단한다")
    func nothingDoneShields() {
        #expect(FocusUnlockRule.evaluate(
            completed: 0, total: 3, requiredRate: 0.8, alreadyUnlockedToday: false) == .shield)
    }

    // MARK: 어긋난 입력

    @Test("완료 수가 전체를 넘어도 1을 넘지 않는다")
    func rateNeverExceedsOne() {
        #expect(FocusUnlockRule.completionRate(completed: 12, total: 10) == 1)
    }

    @Test("음수 완료 수는 0으로 본다")
    func negativeCompletedClamps() {
        #expect(FocusUnlockRule.completionRate(completed: -3, total: 10) == 0)
    }

    @Test("전체가 0이면 완료율은 0이다 — 0으로 나누지 않는다")
    func zeroTotalRate() {
        #expect(FocusUnlockRule.completionRate(completed: 0, total: 0) == 0)
    }

    @Test("완료 수가 전체를 넘는 어긋난 입력도 풀린다")
    func overCompletedUnlocks() {
        let outcome = FocusUnlockRule.evaluate(
            completed: 12, total: 10, requiredRate: 1.0, alreadyUnlockedToday: false)
        #expect(outcome == .unlocked(.goalReached))
    }

    // MARK: 강도

    @Test("기본 강도는 보통이다 — 처음 켜는 사용자에게 엄격을 주지 않는다")
    func defaultStrengthIsNormal() {
        #expect(FocusStrength.default == .normal)
    }

    @Test("강도는 세 단계이고 저장값이 왕복한다")
    func strengthRoundTrips() {
        #expect(FocusStrength.allCases.count == 3)
        for level in FocusStrength.allCases {
            #expect(FocusStrength(rawValue: level.rawValue) == level)
        }
    }

    @Test("모든 강도에 설명이 있다 — 고르는 사람이 차이를 알아야 한다")
    func everyStrengthExplains() {
        for level in FocusStrength.allCases {
            #expect(!level.label.isEmpty)
            #expect(!level.explanation.isEmpty)
        }
    }
}
