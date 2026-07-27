import Testing
@testable import Studion

/// `docs/03-domain-logic.md` §1의 테스트 벡터를 그대로 옮긴 것이다.
/// 명세가 바뀌면 문서와 이 파일을 함께 갱신한다.
private let tolerance = 0.0001

// MARK: - §1-1 누적 비율 → 등급

@Suite("§1-1 누적 비율 → 등급")
struct TopRatioToGradeTests {

    @Test("5등급제 경계 매핑", arguments: [
        (0.01, 1), (0.10, 1), (0.1001, 2), (0.34, 2),
        (0.50, 3), (0.90, 4), (0.95, 5), (1.00, 5),
    ])
    func fiveTier(topRatio: Double, expected: Int) {
        #expect(GradeCalculator.grade(forTopRatio: topRatio, system: .fiveTier) == expected)
    }

    @Test("9등급제 경계 매핑", arguments: [
        (0.04, 1), (0.0401, 2), (0.11, 2), (0.23, 3), (0.40, 4),
        (0.60, 5), (0.77, 6), (0.89, 7), (0.96, 8), (1.00, 9),
    ])
    func nineTier(topRatio: Double, expected: Int) {
        #expect(GradeCalculator.grade(forTopRatio: topRatio, system: .nineTier) == expected)
    }

    @Test("범위 밖 입력은 nil", arguments: [0.0, 1.01, -0.1])
    func outOfRange(topRatio: Double) {
        #expect(GradeCalculator.grade(forTopRatio: topRatio, system: .fiveTier) == nil)
        #expect(GradeCalculator.grade(forTopRatio: topRatio, system: .nineTier) == nil)
    }

    @Test("경계값은 해당 등급에 포함된다 — 5등급제 전 경계 확인")
    func boundariesAreInclusive() {
        let boundaries = GradingSystemType.fiveTier.cumulativeBoundaries
        for (index, boundary) in boundaries.enumerated() {
            #expect(GradeCalculator.grade(forTopRatio: boundary, system: .fiveTier) == index + 1)
        }
    }
}

// MARK: - §1-2 석차 → 등급

@Suite("§1-2 석차 → 등급")
struct RankToGradeTests {

    @Test("동점 없음 / 있음 매핑", arguments: [
        (30, 300, 1, GradingSystemType.fiveTier, 1),
        (31, 300, 1, GradingSystemType.fiveTier, 2),
        (28, 300, 5, GradingSystemType.fiveTier, 2),
        (1, 300, 1, GradingSystemType.nineTier, 1),
        (300, 300, 1, GradingSystemType.nineTier, 9),
    ])
    func validInputs(rank: Int, count: Int, tie: Int, system: GradingSystemType, expected: Int) {
        #expect(
            GradeCalculator.grade(rank: rank, studentCount: count, tieCount: tie, system: system)
                == expected
        )
    }

    @Test("유효하지 않은 입력은 nil", arguments: [
        (0, 300, 1),    // rank < 1
        (30, 0, 1),     // studentCount < 1
        (299, 300, 5),  // rank + tie - 1 > studentCount
        (30, 300, 0),   // tieCount < 1
    ])
    func invalidInputs(rank: Int, count: Int, tie: Int) {
        #expect(
            GradeCalculator.grade(rank: rank, studentCount: count, tieCount: tie, system: .fiveTier)
                == nil
        )
    }

    @Test("동점자가 없으면 tieCount 기본값으로 rank/N에 환원된다")
    func tieCountDefaultsToOne() {
        let withDefault = GradeCalculator.grade(rank: 30, studentCount: 300, system: .fiveTier)
        let explicit = GradeCalculator.grade(rank: 30, studentCount: 300, tieCount: 1, system: .fiveTier)
        #expect(withDefault == explicit)
    }

    @Test("동점자가 많을수록 불리하다")
    func moreTiesIsWorseOrEqual() {
        let alone = GradeCalculator.grade(rank: 28, studentCount: 300, tieCount: 1, system: .fiveTier)
        let tied = GradeCalculator.grade(rank: 28, studentCount: 300, tieCount: 5, system: .fiveTier)
        #expect(alone != nil && tied != nil)
        #expect(tied! >= alone!)
    }
}

// MARK: - §1-3 원점수 → 예상 등급 (추정치)

@Suite("§1-3 원점수 → 예상 등급")
struct EstimateGradeTests {

    @Test("z점수와 상위 비율 추정", arguments: [
        (90.0, 2.0, 0.02275),
        (80.0, 1.0, 0.15866),
        (70.0, 0.0, 0.50000),
        (60.0, -1.0, 0.84134),
        (50.0, -2.0, 0.97725),
    ])
    func zScoreAndTopRatio(rawScore: Double, expectedZ: Double, expectedTopRatio: Double) throws {
        let result = try #require(
            GradeCalculator.estimateGrade(
                rawScore: rawScore, subjectAverage: 70, stdDeviation: 10, system: .fiveTier
            )
        )
        #expect(abs(result.zScore - expectedZ) < tolerance)
        #expect(abs(result.estimatedTopRatio - expectedTopRatio) < tolerance)
    }

    @Test("제도별 추정 등급", arguments: [
        (90.0, 1, 1),
        (80.0, 2, 3),
        (70.0, 3, 5),
        (60.0, 4, 7),
        (50.0, 5, 9),
    ])
    func estimatedGradePerSystem(rawScore: Double, fiveTier: Int, nineTier: Int) throws {
        let five = try #require(
            GradeCalculator.estimateGrade(
                rawScore: rawScore, subjectAverage: 70, stdDeviation: 10, system: .fiveTier
            )
        )
        let nine = try #require(
            GradeCalculator.estimateGrade(
                rawScore: rawScore, subjectAverage: 70, stdDeviation: 10, system: .nineTier
            )
        )
        #expect(five.estimatedGrade == fiveTier)
        #expect(nine.estimatedGrade == nineTier)
    }

    @Test("표준편차가 0 이하이면 nil", arguments: [0.0, -5.0])
    func invalidStdDeviation(stdDev: Double) {
        #expect(
            GradeCalculator.estimateGrade(
                rawScore: 85, subjectAverage: 70, stdDeviation: stdDev, system: .fiveTier
            ) == nil
        )
    }

    @Test("isEstimate는 항상 true다")
    func alwaysMarkedAsEstimate() throws {
        let result = try #require(
            GradeCalculator.estimateGrade(
                rawScore: 90, subjectAverage: 70, stdDeviation: 10, system: .fiveTier
            )
        )
        #expect(result.isEstimate)
    }

    @Test("극단적으로 높은 점수도 크래시 없이 1등급을 낸다")
    func extremeHighScoreClamps() throws {
        let result = try #require(
            GradeCalculator.estimateGrade(
                rawScore: 1000, subjectAverage: 50, stdDeviation: 1, system: .fiveTier
            )
        )
        #expect(result.estimatedGrade == 1)
        #expect(result.estimatedTopRatio > 0)
    }
}

// MARK: - §1-4 이수단위 가중 평균 등급

@Suite("§1-4 이수단위 가중 평균")
struct WeightedAverageGradeTests {

    @Test("정상 입력")
    func validInputs() throws {
        let a = try #require(GradeCalculator.weightedAverageGrade([
            .init(grade: 2, creditUnits: 4),
            .init(grade: 3, creditUnits: 4),
            .init(grade: 1, creditUnits: 4),
        ]))
        #expect(abs(a - 2.0) < tolerance)

        let b = try #require(GradeCalculator.weightedAverageGrade([
            .init(grade: 1, creditUnits: 3),
            .init(grade: 3, creditUnits: 4),
        ]))
        #expect(abs(b - 15.0 / 7.0) < tolerance)

        let c = try #require(GradeCalculator.weightedAverageGrade([
            .init(grade: 2, creditUnits: 4),
        ]))
        #expect(abs(c - 2.0) < tolerance)
    }

    @Test("빈 배열은 nil")
    func emptyInput() {
        #expect(GradeCalculator.weightedAverageGrade([]) == nil)
    }

    @Test("총 이수단위가 0이면 nil")
    func zeroTotalUnits() {
        #expect(GradeCalculator.weightedAverageGrade([.init(grade: 2, creditUnits: 0)]) == nil)
    }

    @Test("이수단위가 큰 과목이 평균을 더 끌어당긴다")
    func weightingActuallyApplies() throws {
        let heavy = try #require(GradeCalculator.weightedAverageGrade([
            .init(grade: 1, creditUnits: 10),
            .init(grade: 5, creditUnits: 1),
        ]))
        #expect(heavy < 2.0)
    }
}
