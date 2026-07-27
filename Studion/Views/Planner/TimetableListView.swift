import SwiftUI
import SwiftData

/// 등록된 시간표 전체 관리. 요일별로 묶어 보여준다.
struct TimetableListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar

    @Query(sort: \TimetableEntry.startTime) private var entries: [TimetableEntry]

    @State private var isAdding = false
    @State private var entryToEdit: TimetableEntry?

    /// 월요일 시작 순서로 묶는다.
    private var groupedByDisplayIndex: [(index: Int, entries: [TimetableEntry])] {
        let grouped = Dictionary(grouping: entries) {
            PlannerDateHelper.displayIndex(forCalendarWeekday: $0.dayOfWeek)
        }
        return grouped.keys.sorted().map { index in
            let sorted = (grouped[index] ?? []).sorted {
                PlannerDateHelper.minutesOfDay($0.startTime, calendar: calendar)
                    < PlannerDateHelper.minutesOfDay($1.startTime, calendar: calendar)
            }
            return (index, sorted)
        }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyStateView(
                    systemImage: "calendar.badge.plus",
                    title: "등록된 시간표가 없어요",
                    message: "학교와 학원 일정을 등록하면 플래너에 표시됩니다.",
                    actionTitle: "시간표 추가",
                    action: { isAdding = true }
                )
            } else {
                List {
                    ForEach(groupedByDisplayIndex, id: \.index) { group in
                        Section(weekdayName(displayIndex: group.index)) {
                            ForEach(group.entries) { entry in
                                Button {
                                    entryToEdit = entry
                                } label: {
                                    TimetableBlockView(
                                        title: entry.title,
                                        type: entry.type,
                                        startTime: entry.startTime,
                                        endTime: entry.endTime
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                delete(group.entries, at: offsets)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("시간표 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAdding = true
                } label: {
                    Label("시간표 추가", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) { TimetableFormView() }
        .sheet(item: $entryToEdit) { entry in TimetableFormView(editing: entry) }
    }

    private func weekdayName(displayIndex index: Int) -> String {
        let weekday = PlannerDateHelper.calendarWeekday(forDisplayIndex: index)
        return calendar.weekdaySymbols[weekday - 1]
    }

    private func delete(_ group: [TimetableEntry], at offsets: IndexSet) {
        for index in offsets {
            context.delete(group[index])
        }
    }
}
