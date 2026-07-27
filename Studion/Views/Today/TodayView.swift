import SwiftUI
import SwiftData

/// 오늘 탭. 앱을 열자마자 "오늘 뭘 해야 하나"에 답한다.
///
/// ① 오늘의 시간표 요약 ② 오늘의 할 일 ③ 이번 학기 진척 요약 세 섹션으로 구성되며,
/// 추가 버튼은 툴바의 `+` **하나만** 둔다.
struct TodayView: View {
    /// 시간표 요약에 보여줄 최대 개수. 길어져도 고정 높이로 자르지 않고 개수를 제한한다.
    private static let maxScheduleItems = 3
    /// 진척 요약에 보여줄 최대 과목 수.
    private static let maxProgressItems = 3

    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar

    @Query private var allEntries: [TimetableEntry]
    @Query private var allPlanItems: [PlanItem]

    @Query(sort: [SortDescriptor(\Semester.year, order: .reverse),
                  SortDescriptor(\Semester.term, order: .reverse)])
    private var semesters: [Semester]

    @State private var isAddingPlanItem = false

    private var today: Date { PlannerDateHelper.startOfDay(Date(), calendar: calendar) }

    private var todaysEntries: [TimetableEntry] {
        let weekday = PlannerDateHelper.calendarWeekday(of: today, calendar: calendar)
        return allEntries
            .filter { $0.dayOfWeek == weekday }
            .sorted {
                PlannerDateHelper.minutesOfDay($0.startTime, calendar: calendar)
                    < PlannerDateHelper.minutesOfDay($1.startTime, calendar: calendar)
            }
    }

    private var todaysPlanItems: [PlanItem] {
        allPlanItems
            .filter { PlannerDateHelper.isSameDay($0.date, today, calendar: calendar) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var latestSemester: Semester? { semesters.first }

    private var progressItems: [SemesterProgressCard.Item] {
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

    private var isEverythingEmpty: Bool {
        todaysEntries.isEmpty && todaysPlanItems.isEmpty && progressItems.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEverythingEmpty {
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "오늘 할 일이 없어요",
                        message: "할 일을 추가하면 여기에 표시됩니다.",
                        actionTitle: "할 일 추가",
                        action: { isAddingPlanItem = true }
                    )
                } else {
                    content
                }
            }
            .navigationTitle("오늘")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingPlanItem = true
                    } label: {
                        Label("할 일 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingPlanItem) {
                PlanItemFormView(defaultDate: today)
            }
        }
    }

    private var content: some View {
        List {
            Section("오늘의 시간표") {
                if todaysEntries.isEmpty {
                    Text("오늘 등록된 일정이 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todaysEntries.prefix(Self.maxScheduleItems)) { entry in
                        TimetableBlockView(
                            title: entry.title,
                            type: entry.type,
                            startTime: entry.startTime,
                            endTime: entry.endTime
                        )
                    }
                    if todaysEntries.count > Self.maxScheduleItems {
                        Text("외 \(todaysEntries.count - Self.maxScheduleItems)개 일정")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("오늘의 할 일") {
                if todaysPlanItems.isEmpty {
                    Text("오늘 할 일이 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todaysPlanItems) { item in
                        PlanItemRow(
                            title: item.title,
                            isDone: item.isDone,
                            relatedSubjectName: item.relatedSubjectName
                        ) {
                            // 체크는 즉시 저장한다. 별도 저장 버튼을 두지 않는다.
                            item.isDone.toggle()
                        }
                    }
                    .onDelete(perform: deletePlanItems)
                }
            }

            if let latestSemester, !progressItems.isEmpty {
                Section("이번 학기 진척") {
                    SemesterProgressCard(
                        semesterName: latestSemester.displayName,
                        items: Array(progressItems.prefix(Self.maxProgressItems)),
                        hiddenCount: max(0, progressItems.count - Self.maxProgressItems)
                    )
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func deletePlanItems(at offsets: IndexSet) {
        for index in offsets {
            context.delete(todaysPlanItems[index])
        }
    }
}

#Preview {
    TodayView()
}
