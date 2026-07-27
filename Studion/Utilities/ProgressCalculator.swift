import Foundation

/// 목표 대비 진척과 회차별 추이 요약.
///
/// 순수 Swift로만 구현한다 — SwiftData·SwiftUI·Charts를 import하지 않는다.
/// 명세와 테스트 벡터: `docs/03-domain-logic.md` §2
enum ProgressCalculator {

    // MARK: - 목표 대비 진척

    struct GradeProgress: Equatable {
        /// 목표까지 남은 등급 수. 0 이하이면 달성.
        let remainingTiers: Int
        let isAchieved: Bool
        /// 게이지 표시용 0...1
        let ratio: Double
    }

    /// 현재 등급과 목표 등급을 비교한다. **등급은 작을수록 좋다.**
    /// - Returns: `current`/`target`이 `1...tierCount` 범위를 벗어나면 `nil`
    static func progress(current: Int, target: Int, system: GradingSystemType) -> GradeProgress? {
        let worst = system.tierCount
        guard (1...worst).contains(current), (1...worst).contains(target) else { return nil }

        let remainingTiers = current - target
        let isAchieved = current <= target

        let ratio: Double
        if target >= worst {
            // 목표가 최하 등급이면 분모가 0이 된다. 달성 여부로만 판단한다.
            ratio = isAchieved ? 1.0 : 0.0
        } else {
            let raw = Double(worst - current) / Double(worst - target)
            ratio = min(max(raw, 0.0), 1.0)
        }

        return GradeProgress(remainingTiers: remainingTiers, isAchieved: isAchieved, ratio: ratio)
    }

    // MARK: - 회차별 추이

    struct TrendPoint: Equatable {
        let date: Date
        let value: Double

        init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    struct TrendSummary: Equatable {
        let average: Double
        /// 모표준편차(n). 전체 회차가 모집단이므로 표본 표준편차를 쓰지 않는다.
        let stdDeviation: Double
        /// 최신값 - 직전값. 점이 1개 이하이면 `nil`.
        ///
        /// - Important: **등급 추이에서는 부호의 의미가 반대다.** `3 → 2`는 `-1`이지만 향상이다.
        ///   부호 해석과 문구 반전은 호출부(UI)의 책임이며, 이 값 자체를 뒤집지 않는다
        ///   (뒤집으면 백분위·표준점수 추이가 틀어진다).
        let latestDelta: Double?
    }

    /// 회차별 추이 요약. 입력을 내부에서 날짜 오름차순으로 정렬하므로
    /// 호출부가 미리 정렬해 줄 필요가 없다.
    /// - Returns: 입력이 비면 `nil`
    static func summarize(_ points: [TrendPoint]) -> TrendSummary? {
        guard !points.isEmpty else { return nil }

        let sorted = points.sorted { $0.date < $1.date }
        let values = sorted.map(\.value)

        let average = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count)
        let stdDeviation = variance.squareRoot()

        let latestDelta: Double? = values.count >= 2
            ? values[values.count - 1] - values[values.count - 2]
            : nil

        return TrendSummary(average: average, stdDeviation: stdDeviation, latestDelta: latestDelta)
    }
}
