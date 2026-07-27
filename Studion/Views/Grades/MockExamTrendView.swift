import SwiftUI
import SwiftData
import Charts

/// 회차별 추이 그래프. 지표(등급/백분위/표준점수)와 과목을 선택해서 본다.
struct MockExamTrendView: View {

    /// 표시 지표.
    private enum Metric: String, CaseIterable, Identifiable {
        case grade, percentile, standardScore

        var id: String { rawValue }

        var title: String {
            switch self {
            case .grade: String(localized: "등급")
            case .percentile: String(localized: "백분위")
            case .standardScore: String(localized: "표준점수")
            }
        }

        /// 등급만 값이 작을수록 좋다. 이 경우에만 y축을 뒤집는다.
        var isLowerBetter: Bool { self == .grade }

        func value(from record: MockExamSubjectRecord) -> Double? {
            switch self {
            case .grade: record.grade.map(Double.init)
            case .percentile: record.percentile
            case .standardScore: record.standardScore
            }
        }
    }

    @Query(sort: \MockExamSession.examDate) private var sessions: [MockExamSession]

    @State private var metric: Metric = .grade
    @State private var selectedSubject: String?

    /// 기록된 과목명 목록. 하드코딩하지 않고 사용자가 입력한 값에서 모은다.
    private var subjectNames: [String] {
        let names = sessions
            .flatMap { $0.subjectRecords ?? [] }
            .map(\.subjectName)
        return Array(Set(names)).sorted()
    }

    private var activeSubject: String? {
        selectedSubject ?? subjectNames.first
    }

    /// 선택 과목의 회차별 값. **값이 없는 회차는 0으로 대체하지 않고 건너뛴다.**
    private var dataPoints: [(session: MockExamSession, value: Double)] {
        guard let activeSubject else { return [] }
        return sessions.compactMap { session in
            guard let record = (session.subjectRecords ?? [])
                .first(where: { $0.subjectName == activeSubject }),
                  let value = metric.value(from: record)
            else { return nil }
            return (session, value)
        }
    }

    private var summary: ProgressCalculator.TrendSummary? {
        ProgressCalculator.summarize(
            dataPoints.map { .init(date: $0.session.examDate, value: $0.value) }
        )
    }

    var body: some View {
        Group {
            if subjectNames.isEmpty {
                EmptyStateView(
                    systemImage: "chart.xyaxis.line",
                    title: "표시할 기록이 없어요",
                    message: "회차에 과목 성적을 입력하면 추이가 그려집니다."
                )
            } else {
                List {
                    Section {
                        Picker("지표", selection: $metric) {
                            ForEach(Metric.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("과목", selection: Binding(
                            get: { activeSubject },
                            set: { selectedSubject = $0 }
                        )) {
                            ForEach(subjectNames, id: \.self) { name in
                                Text(name).tag(Optional(name))
                            }
                        }
                    }

                    Section {
                        if dataPoints.count >= 2 {
                            chart
                        } else if let single = dataPoints.first {
                            // 점 하나짜리 차트를 그리지 않는다.
                            LabeledContent("현재 값") {
                                Text(single.value.formatted(.number.precision(.fractionLength(0...1))))
                                    .monospacedDigit()
                            }
                        } else {
                            Text("이 과목에 \(metric.title) 기록이 없습니다.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let summary, dataPoints.count >= 2 {
                        Section("요약") {
                            LabeledContent("평균") {
                                Text(summary.average.formatted(.number.precision(.fractionLength(2))))
                                    .monospacedDigit()
                            }
                            LabeledContent("표준편차") {
                                Text(summary.stdDeviation.formatted(.number.precision(.fractionLength(2))))
                                    .monospacedDigit()
                            }
                            if let delta = summary.latestDelta {
                                LabeledContent("직전 회차 대비") {
                                    Text(deltaText(delta))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("회차별 추이")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chart: some View {
        Chart(dataPoints, id: \.session.persistentModelID) { point in
            LineMark(
                x: .value("시험일", point.session.examDate),
                y: .value(metric.title, point.value)
            )
            PointMark(
                x: .value("시험일", point.session.examDate),
                y: .value(metric.title, point.value)
            )
        }
        // 등급은 작을수록 좋으므로 축을 뒤집어 1등급이 위로 오게 한다.
        // 값 자체를 변환(10 - grade)해 우회하지 않는다 — 눈금 레이블이 실제 등급이어야 한다.
        .chartYScale(domain: yDomain)
        .frame(minHeight: 200)
        .accessibilityLabel("\(activeSubject ?? "") \(metric.title) 추이")
        .accessibilityValue(accessibilitySummary)
    }

    /// 배열 도메인의 **순서**가 축 방향을 결정한다.
    /// 등급은 `[9, 1]`로 주어 1등급이 위로 오게 하고, 백분위·표준점수는 뒤집지 않는다.
    private var yDomain: [Double] {
        if metric.isLowerBetter { return [9, 1] }

        let values = dataPoints.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let padding = max((high - low) * 0.1, 1)
        return [low - padding, high + padding]
    }

    private var accessibilitySummary: String {
        guard let summary else { return String(localized: "기록 없음") }
        let average = summary.average.formatted(.number.precision(.fractionLength(2)))
        guard let delta = summary.latestDelta else {
            return String(localized: "회차 \(dataPoints.count)개, 평균 \(average)")
        }
        return String(localized: "회차 \(dataPoints.count)개, 평균 \(average), 직전 대비 \(deltaText(delta))")
    }

    /// 등급은 값이 작아지는 것이 향상이다. **부호 해석은 여기(UI)의 책임**이며
    /// `ProgressCalculator`는 순수한 뺄셈 결과만 돌려준다.
    private func deltaText(_ delta: Double) -> String {
        let magnitude = abs(delta).formatted(.number.precision(.fractionLength(0...1)))
        if delta == 0 { return String(localized: "변화 없음") }

        let improved = metric.isLowerBetter ? delta < 0 : delta > 0
        return improved
            ? String(localized: "\(magnitude) 향상")
            : String(localized: "\(magnitude) 하락")
    }
}
