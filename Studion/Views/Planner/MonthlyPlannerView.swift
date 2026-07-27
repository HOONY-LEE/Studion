import SwiftUI
import SwiftData

/// 월간 뷰. 날짜별 완료율을 색 농도로 표시한다 (절제된 단색 농도).
struct MonthlyPlannerView: View {
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date

    @Query private var allPlanItems: [PlanItem]

    private var gridDates: [Date] {
        PlannerDateHelper.monthGridDates(for: selectedDate, calendar: calendar)
    }

    private var currentMonth: Int {
        calendar.component(.month, from: selectedDate)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        List {
            Section {
                monthNavigator
            }

            Section {
                VStack(spacing: 8) {
                    weekdayHeader
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(gridDates, id: \.self) { date in
                            cell(for: date)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("선택한 날") {
                selectedDaySummary
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                move(byMonths: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("지난 달")

            Spacer()

            Text(selectedDate.formatted(.dateTime.year().month()))
                .font(.headline)

            Spacer()

            Button {
                move(byMonths: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("다음 달")
        }
        .buttonStyle(.plain)
    }

    /// 월요일 시작 순서의 요일 헤더.
    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                let weekday = PlannerDateHelper.calendarWeekday(forDisplayIndex: index)
                Text(calendar.shortWeekdaySymbols[weekday - 1])
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func cell(for date: Date) -> some View {
        let items = planItems(on: date)
        let completed = items.filter(\.isDone).count
        let level = PlannerDateHelper.heatLevel(completed: completed, total: items.count)

        return Button {
            selectedDate = date
        } label: {
            CompletionHeatCell(
                day: calendar.component(.day, from: date),
                heatLevel: level,
                isInCurrentMonth: calendar.component(.month, from: date) == currentMonth,
                isSelected: PlannerDateHelper.isSameDay(date, selectedDate, calendar: calendar),
                completedCount: completed,
                totalCount: items.count
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedDaySummary: some View {
        let items = planItems(on: selectedDate)
        let completed = items.filter(\.isDone).count

        VStack(alignment: .leading, spacing: 4) {
            Text(selectedDate.formatted(.dateTime.month().day().weekday(.wide)))
                .font(.subheadline.weight(.medium))
            if items.isEmpty {
                Text("할 일이 없습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("할 일 \(items.count)개 중 \(completed)개 완료")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func planItems(on date: Date) -> [PlanItem] {
        allPlanItems.filter { PlannerDateHelper.isSameDay($0.date, date, calendar: calendar) }
    }

    private func move(byMonths months: Int) {
        guard let moved = calendar.date(byAdding: .month, value: months, to: selectedDate) else { return }
        withAnimation {
            selectedDate = PlannerDateHelper.startOfDay(moved, calendar: calendar)
        }
    }
}
