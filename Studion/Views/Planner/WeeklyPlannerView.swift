import SwiftUI
import SwiftData

/// 주간 뷰. 요일별 컬럼에 할 일 개수와 완료율을 표시한다.
struct WeeklyPlannerView: View {
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date

    @Query private var allPlanItems: [PlanItem]
    @Query private var allEntries: [TimetableEntry]

    private var weekDates: [Date] {
        PlannerDateHelper.weekDates(containing: selectedDate, calendar: calendar)
    }

    var body: some View {
        List {
            Section {
                weekNavigator
            }

            Section("요일별") {
                ForEach(weekDates, id: \.self) { date in
                    dayRow(for: date)
                }
            }
        }
    }

    private var weekNavigator: some View {
        HStack {
            Button {
                move(byWeeks: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("지난 주")

            Spacer()

            if let first = weekDates.first, let last = weekDates.last {
                Text("\(first.formatted(.dateTime.month().day())) – \(last.formatted(.dateTime.month().day()))")
                    .font(.headline)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                move(byWeeks: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("다음 주")
        }
        .buttonStyle(.plain)
    }

    private func dayRow(for date: Date) -> some View {
        let items = planItems(on: date)
        let completed = items.filter(\.isDone).count
        let scheduleCount = entryCount(on: date)
        let isSelected = PlannerDateHelper.isSameDay(date, selectedDate, calendar: calendar)

        return Button {
            selectedDate = date
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(date.formatted(.dateTime.day()))
                        .font(.headline)
                        .monospacedDigit()
                }
                .frame(minWidth: 44)

                VStack(alignment: .leading, spacing: 4) {
                    if items.isEmpty {
                        Text("할 일 없음")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("할 일 \(items.count)개 중 \(completed)개 완료")
                            .font(.subheadline)
                            .monospacedDigit()
                        ProgressView(value: Double(completed), total: Double(items.count))
                            .tint(completed == items.count ? Color("GoalAchieved") : .accentColor)
                    }

                    if scheduleCount > 0 {
                        Text("일정 \(scheduleCount)개")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(date: date, total: items.count, completed: completed))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func accessibilityText(date: Date, total: Int, completed: Int) -> String {
        let day = date.formatted(.dateTime.month().day().weekday(.wide))
        guard total > 0 else { return String(localized: "\(day), 할 일 없음") }
        return String(localized: "\(day), 할 일 \(total)개 중 \(completed)개 완료")
    }

    private func planItems(on date: Date) -> [PlanItem] {
        allPlanItems.filter { PlannerDateHelper.isSameDay($0.date, date, calendar: calendar) }
    }

    private func entryCount(on date: Date) -> Int {
        let weekday = PlannerDateHelper.calendarWeekday(of: date, calendar: calendar)
        return allEntries.filter { $0.dayOfWeek == weekday }.count
    }

    private func move(byWeeks weeks: Int) {
        withAnimation {
            selectedDate = PlannerDateHelper.addingDays(weeks * 7, to: selectedDate, calendar: calendar)
        }
    }
}
