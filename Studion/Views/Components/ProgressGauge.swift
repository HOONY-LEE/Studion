import SwiftUI

/// 목표 대비 진척 게이지.
///
/// 달성/미달을 색상만으로 구분하지 않는다 — 아이콘과 텍스트를 함께 둔다.
/// 미달에 빨간색을 쓰지 않는다 (학생 대상 앱에서 부정적 색채 강조 지양).
struct ProgressGauge: View {
    let progress: ProgressCalculator.GradeProgress
    let currentGrade: Int
    let targetGrade: Int

    private var tint: Color {
        progress.isAchieved ? Color("GoalAchieved") : .secondary
    }

    private var statusText: String {
        progress.isAchieved
            ? String(localized: "목표 달성")
            : String(localized: "목표까지 \(progress.remainingTiers)등급")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: progress.isAchieved ? "checkmark.circle.fill" : "target")
                    .accessibilityHidden(true)
                Text(statusText)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(currentGrade) / 목표 \(targetGrade)등급")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(tint)

            ProgressView(value: progress.ratio)
                .tint(tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "현재 \(currentGrade)등급, 목표 \(targetGrade)등급, \(statusText)"
        )
    }
}

#Preview {
    VStack(spacing: 24) {
        if let achieved = ProgressCalculator.progress(current: 2, target: 2, system: .fiveTier) {
            ProgressGauge(progress: achieved, currentGrade: 2, targetGrade: 2)
        }
        if let behind = ProgressCalculator.progress(current: 3, target: 2, system: .fiveTier) {
            ProgressGauge(progress: behind, currentGrade: 3, targetGrade: 2)
        }
    }
    .padding()
}
