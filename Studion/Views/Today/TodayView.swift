import SwiftUI
import SwiftData

/// 오늘 탭.
///
/// ① 시간표 요약과 ② 할 일 리스트는 5단계에서 채운다. 여기서는 ③ 진척 요약만 연결한다.
struct TodayView: View {
    /// 요약 카드에 보여줄 최대 과목 수. 나머지는 "외 N개"로 접는다.
    private static let maxSummaryItems = 3

    @Query(sort: [SortDescriptor(\Semester.year, order: .reverse),
                  SortDescriptor(\Semester.term, order: .reverse)])
    private var semesters: [Semester]

    private var latestSemester: Semester? { semesters.first }

    private var comparisons: [SemesterProgressCard.Item] {
        guard let latestSemester else { return [] }
        return (latestSemester.subjectRecords ?? [])
            .filter { $0.evaluationType == .achievementAndRank }
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { record in
                guard let actual = record.rankGrade, let target = record.targetGrade else { return nil }
                return SemesterProgressCard.Item(
                    id: record.persistentModelID.storeIdentifier ?? record.subjectName,
                    name: record.subjectName,
                    actual: actual,
                    target: target
                )
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let latestSemester, !comparisons.isEmpty {
                    List {
                        Section {
                            SemesterProgressCard(
                                semesterName: latestSemester.displayName,
                                items: Array(comparisons.prefix(Self.maxSummaryItems)),
                                hiddenCount: max(0, comparisons.count - Self.maxSummaryItems)
                            )
                            .padding(.vertical, 4)
                        } header: {
                            Text("이번 학기 진척")
                        }
                    }
                } else {
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "오늘 할 일이 없어요",
                        message: "할 일을 추가하면 여기에 표시됩니다."
                    )
                }
            }
            .navigationTitle("오늘")
        }
    }
}

#Preview {
    TodayView()
}
