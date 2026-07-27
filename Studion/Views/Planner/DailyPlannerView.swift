import SwiftUI
import SwiftData

/// 일간 뷰. 시간대별 시간표 블록과 그날의 할 일을 함께 보여준다.
struct DailyPlannerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date

    @Query private var allEntries: [TimetableEntry]
    @Query private var allPlanItems: [PlanItem]

    @State private var isAddingPlanItem = false

    /// 선택한 날짜의 요일에 해당하는 시간표. 시작 시각 순으로 정렬한다.
    private var todaysEntries: [TimetableEntry] {
        let weekday = PlannerDateHelper.calendarWeekday(of: selectedDate, calendar: calendar)
        return allEntries
            .filter { $0.dayOfWeek == weekday }
            .sorted {
                PlannerDateHelper.minutesOfDay($0.startTime, calendar: calendar)
                    < PlannerDateHelper.minutesOfDay($1.startTime, calendar: calendar)
            }
    }

    /// 시간표 항목과 겹침 배치 결과를 짝지어 돌려준다.
    ///
    /// 헬퍼는 SwiftData를 모르므로, 여기서 항목마다 임시 UUID를 부여해 값 타입으로 넘기고
    /// 결과를 다시 항목에 붙인다.
    private var entriesWithLayout: [(entry: TimetableEntry, layout: PlannerDateHelper.BlockLayout)] {
        let entries = todaysEntries
        let ids = entries.map { _ in UUID() }

        let ranges = zip(entries, ids).map { entry, id in
            PlannerDateHelper.TimeRange(
                id: id,
                startMinutes: PlannerDateHelper.minutesOfDay(entry.startTime, calendar: calendar),
                endMinutes: PlannerDateHelper.minutesOfDay(entry.endTime, calendar: calendar)
            )
        }

        let layoutByID = Dictionary(
            uniqueKeysWithValues: PlannerDateHelper.layout(ranges).map { ($0.id, $0) }
        )

        return zip(entries, ids).compactMap { entry, id in
            guard let layout = layoutByID[id] else { return nil }
            return (entry, layout)
        }
    }

    private var todaysPlanItems: [PlanItem] {
        allPlanItems
            .filter { PlannerDateHelper.isSameDay($0.date, selectedDate, calendar: calendar) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                dateNavigator
            }

            Section("시간표") {
                if todaysEntries.isEmpty {
                    Text("이 요일에 등록된 일정이 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entriesWithLayout, id: \.entry.persistentModelID) { pair in
                        timelineRow(entry: pair.entry, layout: pair.layout)
                    }
                }
            }

            Section("할 일") {
                if todaysPlanItems.isEmpty {
                    Text("이 날의 할 일이 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todaysPlanItems) { item in
                        PlanItemRow(
                            title: item.title,
                            isDone: item.isDone,
                            relatedSubjectName: item.relatedSubjectName
                        ) {
                            item.isDone.toggle()
                        }
                    }
                    .onDelete(perform: deletePlanItems)
                }

                Button {
                    isAddingPlanItem = true
                } label: {
                    Label("할 일 추가", systemImage: "plus")
                }
            }
        }
        // 좌우 스와이프로 전날/다음날 이동. 위 날짜 네비게이터 버튼이 대안 경로다.
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < 0 {
                        move(by: 1)
                    } else if value.translation.width > 0 {
                        move(by: -1)
                    }
                }
        )
        .sheet(isPresented: $isAddingPlanItem) {
            PlanItemFormView(defaultDate: selectedDate)
        }
    }

    private var dateNavigator: some View {
        HStack {
            Button {
                move(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("전날")

            Spacer()

            VStack(spacing: 2) {
                Text(selectedDate.formatted(.dateTime.year().month().day()))
                    .font(.headline)
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                move(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("다음 날")
        }
        .buttonStyle(.plain)
    }

    /// 겹치는 일정은 나란히 배치한다. 숨기거나 병합하지 않는다.
    @ViewBuilder
    private func timelineRow(
        entry: TimetableEntry,
        layout: PlannerDateHelper.BlockLayout
    ) -> some View {
        if layout.columnCount > 1 {
            HStack(spacing: 6) {
                // 같은 겹침 그룹의 블록이 모두 같은 너비를 갖도록 컬럼 수만큼 나눈다.
                ForEach(0..<layout.columnCount, id: \.self) { column in
                    if column == layout.column {
                        TimetableBlockView(
                            title: entry.title,
                            type: entry.type,
                            startTime: entry.startTime,
                            endTime: entry.endTime,
                            isCompact: true
                        )
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
            }
        } else {
            TimetableBlockView(
                title: entry.title,
                type: entry.type,
                startTime: entry.startTime,
                endTime: entry.endTime
            )
        }
    }

    private func move(by days: Int) {
        withAnimation {
            selectedDate = PlannerDateHelper.addingDays(days, to: selectedDate, calendar: calendar)
        }
    }

    private func deletePlanItems(at offsets: IndexSet) {
        for index in offsets {
            context.delete(todaysPlanItems[index])
        }
    }
}
