import SwiftUI
import SwiftData
import Charts

/// 내신 과목 상세.
///
/// 이 화면은 두 단계가 나눠 만든다 — ① 성적 추이와 ② 목표 진척 게이지가 4단계 몫이고,
/// ③ 오답노트 리스트는 6단계에서 여기에 추가된다.
struct SubjectDetailView: View {
    let record: SchoolSubjectRecord

    @Query(sort: [SortDescriptor(\Semester.year), SortDescriptor(\Semester.term)])
    private var semesters: [Semester]

    private var system: GradingSystemType {
        record.semester?.gradingSystemType ?? .fiveTier
    }

    /// 같은 과목명을 가진 다른 학기의 기록. 과목 동일성은 trim 후 완전 일치로 판정한다.
    private var history: [(semester: Semester, grade: Int)] {
        let name = record.subjectName.trimmed
        return semesters.compactMap { semester in
            guard let match = (semester.subjectRecords ?? []).first(where: {
                $0.subjectName.trimmed == name
            }), let grade = match.rankGrade else { return nil }
            return (semester, grade)
        }
    }

    private var progress: ProgressCalculator.GradeProgress? {
        guard let current = record.rankGrade, let target = record.targetGrade else { return nil }
        return ProgressCalculator.progress(current: current, target: target, system: system)
    }

    var body: some View {
        List {
            Section("성적 추이") {
                if history.count >= 2 {
                    trendChart
                } else if let grade = record.rankGrade {
                    LabeledContent("현재 등급") {
                        Text("\(grade)등급").monospacedDigit()
                    }
                } else {
                    Text("아직 등급 기록이 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("목표 대비") {
                if let progress, let current = record.rankGrade, let target = record.targetGrade {
                    ProgressGauge(progress: progress, currentGrade: current, targetGrade: target)
                        .padding(.vertical, 4)
                } else if record.evaluationType == .achievementOnly {
                    Text("성취도만 기재하는 과목은 목표 등급을 설정하지 않습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("석차등급과 목표 등급을 입력하면 진척이 표시됩니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(record.subjectName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trendChart: some View {
        Chart(history, id: \.semester.persistentModelID) { item in
            LineMark(
                x: .value("학기", item.semester.displayName),
                y: .value("등급", item.grade)
            )
            PointMark(
                x: .value("학기", item.semester.displayName),
                y: .value("등급", item.grade)
            )
        }
        // 등급은 작을수록 좋으므로 1등급이 위로 오게 축을 뒤집는다.
        .chartYScale(domain: [Double(system.tierCount), 1])
        .frame(minHeight: 200)
        .accessibilityLabel("\(record.subjectName) 등급 추이")
        .accessibilityValue("학기 \(history.count)개")
    }
}
