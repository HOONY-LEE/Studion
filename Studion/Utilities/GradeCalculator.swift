import Foundation

/// 내신 등급 산출 로직.
///
/// 순수 Swift로만 구현한다 — SwiftData·SwiftUI를 import하지 않는다.
/// ModelContainer 없이 테스트할 수 있어야 하고, 추후 Android 포팅 시 이 파일이 참조 명세가 된다.
/// 명세와 테스트 벡터: `docs/03-domain-logic.md` §1
enum GradeCalculator {

    // MARK: - 누적 비율 → 등급

    /// 상위 누적 비율을 석차등급으로 변환한다.
    ///
    /// 경계값은 해당 등급에 **포함**된다 (상위 10%까지가 1등급).
    /// - Parameter topRatio: 상위 누적 비율. 유효 범위는 `0 < topRatio <= 1`
    /// - Returns: 1부터 시작하는 등급. 범위를 벗어나면 `nil`
    static func grade(forTopRatio topRatio: Double, system: GradingSystemType) -> Int? {
        guard topRatio > 0, topRatio <= 1 else { return nil }

        let boundaries = system.cumulativeBoundaries
        for (index, boundary) in boundaries.enumerated() where topRatio <= boundary {
            return index + 1
        }
        // 마지막 경계값이 1.0이므로 위 루프에서 반드시 반환된다.
        // 부동소수 오차로 빠져나온 경우에만 최하 등급으로 처리한다.
        return boundaries.count
    }

    // MARK: - 석차 → 등급

    /// 석차와 수강인원으로 등급을 구한다.
    ///
    /// 동점자는 학교생활기록부 규칙에 따라 **가장 불리한 위치**를 기준으로 누적 비율을 계산한다:
    /// `topRatio = (rank + tieCount - 1) / studentCount`
    ///
    /// - Parameters:
    ///   - rank: 석차 (1부터). 동점자가 있으면 그중 가장 높은 석차
    ///   - studentCount: 수강인원
    ///   - tieCount: 동점자 수. 동점이 없으면 1
    /// - Returns: 등급. 입력이 유효하지 않으면 `nil`
    static func grade(
        rank: Int,
        studentCount: Int,
        tieCount: Int = 1,
        system: GradingSystemType
    ) -> Int? {
        guard rank >= 1, studentCount >= 1, tieCount >= 1,
              rank + tieCount - 1 <= studentCount
        else { return nil }

        let topRatio = Double(rank + tieCount - 1) / Double(studentCount)
        return grade(forTopRatio: topRatio, system: system)
    }

    // MARK: - 원점수 → 예상 등급 (추정치)

    /// 정규분포를 가정한 등급 추정 결과.
    ///
    /// - Important: `isEstimate`는 항상 `true`다. 호출부는 이 값을 근거로 화면에 "추정" 배지를 반드시 표시한다.
    struct GradeEstimate: Equatable {
        let zScore: Double
        let estimatedTopRatio: Double
        let estimatedGrade: Int

        var isEstimate: Bool { true }
    }

    /// 원점수·과목평균·표준편차로 등급을 추정한다.
    ///
    /// - Warning: 정규분포 가정에 기반한 **추정치**이며 확정 등급이 아니다.
    ///   사용자가 입력한 확정 석차등급이 있으면 그쪽을 우선 표시한다.
    /// - Returns: `stdDeviation <= 0`이면 `nil`
    static func estimateGrade(
        rawScore: Double,
        subjectAverage: Double,
        stdDeviation: Double,
        system: GradingSystemType
    ) -> GradeEstimate? {
        guard stdDeviation > 0 else { return nil }

        let zScore = (rawScore - subjectAverage) / stdDeviation
        let phi = standardNormalCDF(zScore)

        // 극단값에서 topRatio가 0이 되면 grade(forTopRatio:)가 nil을 반환하므로 하한을 둔다.
        let topRatio = min(max(1 - phi, 1e-9), 1.0)

        guard let estimatedGrade = grade(forTopRatio: topRatio, system: system) else { return nil }

        return GradeEstimate(
            zScore: zScore,
            estimatedTopRatio: topRatio,
            estimatedGrade: estimatedGrade
        )
    }

    /// 표준정규분포 누적분포함수 Φ(z) = 0.5 * (1 + erf(z / √2))
    private static func standardNormalCDF(_ z: Double) -> Double {
        0.5 * (1 + erf(z / 2.0.squareRoot()))
    }

    // MARK: - 이수단위 가중 평균 등급

    struct WeightedGradeInput: Equatable {
        let grade: Int
        let creditUnits: Double

        init(grade: Int, creditUnits: Double) {
            self.grade = grade
            self.creditUnits = creditUnits
        }
    }

    /// 이수단위로 가중한 평균 등급.
    ///
    /// - Important: 성취도만 기재하는 과목(등급 없음)은 **호출부에서 제외해** 전달한다.
    ///   등급이 없는 과목의 이수단위를 분모에 넣으면 평균이 왜곡된다.
    /// - Returns: 유효 입력이 없거나 총 이수단위가 0이면 `nil`
    static func weightedAverageGrade(_ inputs: [WeightedGradeInput]) -> Double? {
        let valid = inputs.filter { $0.creditUnits > 0 }
        guard !valid.isEmpty else { return nil }

        let totalUnits = valid.reduce(0.0) { $0 + $1.creditUnits }
        guard totalUnits > 0 else { return nil }

        let weightedSum = valid.reduce(0.0) { $0 + Double($1.grade) * $1.creditUnits }
        return weightedSum / totalUnits
    }
}
