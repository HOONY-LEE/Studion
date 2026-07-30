import SwiftUI
import SwiftData
import UIKit

/// 플래너의 "월간" — Gradin 월간 뷰를 옮긴 것. 좌우로 달을 넘기고, 칸마다 그날의
/// 시간표·할 일을 짧은 바로 보여준다.
///
/// Gradin에는 여러 날에 걸친 일정을 가로 바로 잇는 레이아웃 계산이 있는데, Studion에는
/// **여러 날에 걸치는 항목이 없다** — 시간표는 매주 같은 요일의 시간 블록이고 할 일은
/// 하루에 속한다. 그래서 그 계산은 옮기지 않았다(없는 경우를 위한 코드를 남기지 않는다).
struct PlannerMonthView: View {
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date

    @Query private var allEntries: [TimetableEntry]
    @Query private var allPlanItems: [PlanItem]

    @State private var scrolledMonthIndex: Int?

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(pageRange, id: \.self) { index in
                        monthPage(monthIndex: index)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledMonthIndex)
            .scrollIndicators(.hidden)
        }
        .onAppear {
            if scrolledMonthIndex == nil {
                scrolledMonthIndex = PlannerDateHelper.monthIndex(for: selectedDate, calendar: calendar)
            }
        }
        .onChange(of: scrolledMonthIndex) { _, newValue in
            guard let newValue,
                  newValue != PlannerDateHelper.monthIndex(for: selectedDate, calendar: calendar)
            else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // 넘긴 달이 이번 달이면 오늘로, 아니면 그 달 1일로 맞춘다 — 달을 오갈 때
            // 오늘이 있는 달로 돌아오면 오늘이 선택돼 있는 게 자연스럽다.
            let monthStart = PlannerDateHelper.monthStart(forMonthIndex: newValue, calendar: calendar)
            let today = PlannerDateHelper.startOfDay(Date(), calendar: calendar)
            selectedDate = calendar.isDate(today, equalTo: monthStart, toGranularity: .month)
                ? today
                : monthStart
        }
        .onChange(of: selectedDate) { _, newValue in
            let index = PlannerDateHelper.monthIndex(for: newValue, calendar: calendar)
            if scrolledMonthIndex != index { scrolledMonthIndex = index }
        }
    }

    private var pageRange: ClosedRange<Int> {
        let center = PlannerDateHelper.monthIndex(for: Date(), calendar: calendar)
        return (center - 600)...(center + 600)
    }

    // MARK: - 한 달

    private func monthPage(monthIndex: Int) -> some View {
        let monthStart = PlannerDateHelper.monthStart(forMonthIndex: monthIndex, calendar: calendar)
        let days = PlannerDateHelper.monthGridDates(for: monthStart, calendar: calendar)
        let rowCount = max(days.count / 7, 1)

        return VStack(spacing: 0) {
            HStack {
                // 연도는 상단 날짜 알약이 이미 보여주므로 큰 제목은 달만 (Gradin과 동일).
                Text(verbatim: monthStart.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 34, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 2)

            PlannerWeekdayHeader()
            Divider()

            GeometryReader { geo in
                let rowHeight = geo.size.height / CGFloat(rowCount)
                VStack(spacing: 0) {
                    ForEach(0..<rowCount, id: \.self) { row in
                        let slice = Array(days[(row * 7)..<min(row * 7 + 7, days.count)])
                        HStack(spacing: 0) {
                            ForEach(slice, id: \.self) { day in
                                dayCell(day, monthStart: monthStart, rowHeight: rowHeight)
                            }
                        }
                        .frame(height: rowHeight)
                        if row < rowCount - 1 { Divider() }
                    }
                }
            }
        }
    }

    /// 한 칸. 셀 높이에 따라 보여줄 바 개수를 정한다 — 주가 적은 달은 칸이 높아 더 담긴다.
    private func dayCell(_ day: Date, monthStart: Date, rowHeight: CGFloat) -> some View {
        let isCurrentMonth = calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let isSelected = PlannerDateHelper.isSameDay(day, selectedDate, calendar: calendar)
        let weekday = calendar.component(.weekday, from: day)
        // 날짜 숫자(30) + 여백을 뺀 높이를 바 높이(17)로 나눈다.
        let maxBars = max(0, Int((rowHeight - 38) / 17))

        return VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(numberColor(isToday: isToday, isSelected: isSelected,
                                             isCurrentMonth: isCurrentMonth, weekday: weekday))
                .frame(width: 28, height: 28)
                .background {
                    if isToday {
                        Circle().fill(Color.accentColor)
                    } else if isSelected {
                        Circle().fill(Color.accentColor.opacity(0.15))
                    }
                }
                .padding(.top, 3)

            bars(for: day, maxBars: maxBars)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .opacity(isCurrentMonth ? 1 : 0.3)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = PlannerDateHelper.startOfDay(day, calendar: calendar)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellLabel(day, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func numberColor(
        isToday: Bool, isSelected: Bool, isCurrentMonth: Bool, weekday: Int
    ) -> Color {
        if isToday { return .white }
        guard isCurrentMonth else { return .secondary }
        return PlannerWeekdayHeader.color(weekday: weekday) == .secondary
            ? .primary
            : PlannerWeekdayHeader.color(weekday: weekday)
    }

    /// 그날의 시간표와 할 일을 짧은 바로. 넘치면 "+n"으로 줄인다.
    @ViewBuilder
    private func bars(for day: Date, maxBars: Int) -> some View {
        let weekday = PlannerDateHelper.calendarWeekday(of: day, calendar: calendar)
        let entries = allEntries
            .filter { $0.dayOfWeek == weekday }
            .sorted {
                PlannerDateHelper.minutesOfDay($0.startTime, calendar: calendar)
                    < PlannerDateHelper.minutesOfDay($1.startTime, calendar: calendar)
            }
        let items = allPlanItems
            .filter { PlannerDateHelper.isSameDay($0.date, day, calendar: calendar) }
            .sorted { $0.createdAt < $1.createdAt }

        let total = entries.count + items.count
        let overflow = total - maxBars
        let visible = overflow > 0 ? max(maxBars - 1, 0) : total

        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(barLabels(entries: entries, items: items).prefix(visible)), id: \.id) { bar in
                Text(verbatim: bar.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(bar.color)
                    .strikethrough(bar.isDone)
                    .padding(.horizontal, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(bar.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            }
            if overflow > 0 {
                Text(verbatim: "+\(total - visible)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 1)
    }

    private struct Bar: Identifiable {
        let id: String
        let title: String
        let color: Color
        let isDone: Bool
    }

    private func barLabels(entries: [TimetableEntry], items: [PlanItem]) -> [Bar] {
        entries.map { entry in
            Bar(
                id: "e\(entry.persistentModelID.hashValue)",
                title: entry.title,
                color: entry.type == .school ? Color("ScheduleSchool") : Color("ScheduleAcademy"),
                isDone: false
            )
        } + items.map { item in
            Bar(
                id: "p\(item.persistentModelID.hashValue)",
                title: item.title,
                // 할 일은 accent로 두어 시간표와 구분한다.
                color: .accentColor,
                isDone: item.isDone
            )
        }
    }

    private func cellLabel(_ day: Date, isToday: Bool) -> String {
        let date = day.formatted(.dateTime.month().day().weekday(.wide))
        let weekday = PlannerDateHelper.calendarWeekday(of: day, calendar: calendar)
        let entryCount = allEntries.filter { $0.dayOfWeek == weekday }.count
        let itemCount = allPlanItems
            .filter { PlannerDateHelper.isSameDay($0.date, day, calendar: calendar) }
            .count

        var parts = [date]
        if isToday { parts.append(String(localized: "오늘")) }
        if entryCount > 0 { parts.append("시간표 \(entryCount)개") }
        if itemCount > 0 { parts.append("할 일 \(itemCount)개") }
        return parts.joined(separator: ", ")
    }
}
