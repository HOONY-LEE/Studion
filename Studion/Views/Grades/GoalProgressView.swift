import SwiftUI
import SwiftData
import Charts

/// 학기별 목표 vs 실제 비교.
///
/// 성취도만 기재하는 과목은 목표 설정 대상이 아니므로 제외한다.
struct GoalProgressView: View {
    let semester: Semester

    private var system: GradingSystemType { semester.gradingSystemType }

    /// 등급이 산출되고 실제·목표가 모두 입력된 과목만 비교 대상이다.
    private var comparisons: [(name: String, actual: Int, target: Int)] {
        (semester.subjectRecords ?? [])
            .filter { $0.evaluationType == .achievementAndRank }
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { record in
                guard let actual = record.rankGrade, let target = record.targetGrade else { return nil }
                return (record.subjectName, actual, target)
            }
    }

    var body: some View {
        Group {
            if comparisons.isEmpty {
                EmptyStateView(
                    systemImage: "target",
                    title: "비교할 목표가 없어요",
                    message: "과목에 석차등급과 목표 등급을 입력하면 여기서 비교할 수 있습니다."
                )
            } else {
                List {
                    Section("목표 vs 실제") {
                        comparisonChart
                    }

                    Section("과목별 진척") {
                        ForEach(comparisons, id: \.name) { item in
                            if let progress = ProgressCalculator.progress(
                                current: item.actual, target: item.target, system: system
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.name).font(.subheadline)
                                    ProgressGauge(
                                        progress: progress,
                                        currentGrade: item.actual,
                                        targetGrade: item.target
                                    )
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("목표 대비 진척")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var comparisonChart: some View {
        Chart {
            ForEach(comparisons, id: \.name) { item in
                BarMark(
                    x: .value("과목", item.name),
                    y: .value("등급", item.actual)
                )
                .foregroundStyle(
                    item.actual <= item.target ? Color("GoalAchieved") : Color.secondary
                )
                .position(by: .value("구분", String(localized: "실제")))

                BarMark(
                    x: .value("과목", item.name),
                    y: .value("등급", item.target)
                )
                .foregroundStyle(.tint)
                .opacity(0.35)
                .position(by: .value("구분", String(localized: "목표")))
            }
        }
        // 1등급이 위로 오게 축을 뒤집는다.
        .chartYScale(domain: [Double(system.tierCount), 1])
        .frame(minHeight: 220)
        .accessibilityLabel("과목별 목표 대비 실제 등급 비교")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let achieved = comparisons.filter { $0.actual <= $0.target }.count
        return String(localized: "과목 \(comparisons.count)개 중 \(achieved)개 목표 달성")
    }
}
