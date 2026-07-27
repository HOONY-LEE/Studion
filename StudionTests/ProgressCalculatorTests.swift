import Foundation
import Testing
@testable import Studion

/// `docs/03-domain-logic.md` §2의 테스트 벡터를 그대로 옮긴 것이다.
private let tolerance = 0.0001

/// 결정적인 날짜를 만든다 (Asia/Seoul 고정). 테스트에 `Date()`를 쓰지 않는다.
private func date(_ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar.date(from: DateComponents(year: 2026, month: 3, day: day))!
}

// MARK: - §2-1 목표 대비 진척

@Suite("§2-1 목표 대비 진척")
struct GradeProgressTests {

    @Test("5등급제 진척 표", arguments: [
        (3, 2, 1, false, 0.6667),
        (2, 2, 0, true, 1.0),
        (1, 2, -1, true, 1.0),
        (5, 2, 3, false, 0.0),
        (3, 1, 2, false, 0.5),
        (5, 5, 0, true, 1.0),
        (4, 5, -1, true, 1.0),
    ])
    func fiveTierTable(current: Int, target: Int, remaining: Int, achieved: Bool, ratio: Double) throws {
        let result = try #require(
            ProgressCalculator.progress(current: current, target: target, system: .fiveTier)
        )
        #expect(result.remainingTiers == remaining)
        #expect(result.isAchieved == achieved)
        #expect(abs(result.ratio - ratio) < tolerance)
    }

    @Test("5등급제 범위 밖 입력은 nil", arguments: [(0, 2), (6, 2), (3, 0), (3, 6)])
    func fiveTierOutOfRange(current: Int, target: Int) {
        #expect(ProgressCalculator.progress(current: current, target: target, system: .fiveTier) == nil)
    }

    @Test("9등급제 범위 밖 입력은 nil", arguments: [(0, 2), (10, 2), (3, 0), (3, 10)])
    func nineTierOutOfRange(current: Int, target: Int) {
        #expect(ProgressCalculator.progress(current: current, target: target, system: .nineTier) == nil)
    }

    @Test("9등급제는 1...9를 허용한다")
    func nineTierAcceptsFullRange() throws {
        let result = try #require(
            ProgressCalculator.progress(current: 9, target: 1, system: .nineTier)
        )
        #expect(result.remainingTiers == 8)
        #expect(result.isAchieved == false)
        #expect(abs(result.ratio - 0.0) < tolerance)
    }

    @Test("목표가 최하 등급이면 분모 0 분기로 처리된다")
    func zeroDenominatorBranch() throws {
        let achieved = try #require(ProgressCalculator.progress(current: 9, target: 9, system: .nineTier))
        #expect(abs(achieved.ratio - 1.0) < tolerance)

        let alsoAchieved = try #require(ProgressCalculator.progress(current: 3, target: 9, system: .nineTier))
        #expect(alsoAchieved.isAchieved)
        #expect(abs(alsoAchieved.ratio - 1.0) < tolerance)
    }

    @Test("ratio는 0...1을 벗어나지 않는다")
    func ratioIsClamped() throws {
        let over = try #require(ProgressCalculator.progress(current: 1, target: 2, system: .fiveTier))
        #expect(over.ratio <= 1.0)

        let under = try #require(ProgressCalculator.progress(current: 5, target: 2, system: .fiveTier))
        #expect(under.ratio >= 0.0)
    }
}

// MARK: - §2-2 모의고사 추이

@Suite("§2-2 모의고사 추이")
struct TrendSummaryTests {

    private func points(_ values: [Double]) -> [ProgressCalculator.TrendPoint] {
        values.enumerated().map { .init(date: date(1 + $0.offset), value: $0.element) }
    }

    @Test("추이 요약 표")
    func summaryTable() throws {
        // 등급이라면 3 → 2는 향상이다. 부호를 뒤집는 책임은 UI에 있다.
        let a = try #require(ProgressCalculator.summarize(points([3, 3, 2])))
        #expect(abs(a.average - 2.6667) < tolerance)
        #expect(abs(a.stdDeviation - 0.4714) < tolerance)
        #expect(abs(try #require(a.latestDelta) - (-1.0)) < tolerance)

        // latestDelta는 마지막 두 값의 차다. 전체 추세가 아니다.
        let flat = try #require(ProgressCalculator.summarize(points([3, 2, 2])))
        #expect(abs(flat.average - 2.3333) < tolerance)
        #expect(abs(try #require(flat.latestDelta) - 0.0) < tolerance)

        let b = try #require(ProgressCalculator.summarize(points([80])))
        #expect(abs(b.average - 80.0) < tolerance)
        #expect(abs(b.stdDeviation - 0.0) < tolerance)
        #expect(b.latestDelta == nil)

        let c = try #require(ProgressCalculator.summarize(points([1, 2])))
        #expect(abs(c.average - 1.5) < tolerance)
        #expect(abs(c.stdDeviation - 0.5) < tolerance)
        #expect(abs(try #require(c.latestDelta) - 1.0) < tolerance)
    }

    @Test("빈 배열은 nil")
    func emptyInput() {
        #expect(ProgressCalculator.summarize([]) == nil)
    }

    @Test("입력 순서가 달라도 결과가 같다 — 내부에서 날짜순 정렬한다")
    func orderIndependence() throws {
        let ascending = points([3, 3, 2])
        let shuffled = Array(ascending.reversed())

        let a = try #require(ProgressCalculator.summarize(ascending))
        let b = try #require(ProgressCalculator.summarize(shuffled))
        #expect(a == b)
        #expect(abs(try #require(b.latestDelta) - (-1.0)) < tolerance)
    }

    @Test("모표준편차(n)를 쓴다 — 표본 표준편차(n-1)가 아니다")
    func populationStandardDeviation() throws {
        // [1, 3]: 모표준편차 = 1.0, 표본 표준편차 ≈ 1.4142
        let result = try #require(ProgressCalculator.summarize(points([1, 3])))
        #expect(abs(result.stdDeviation - 1.0) < tolerance)
    }
}
