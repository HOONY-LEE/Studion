import SwiftUI
import SwiftData
import UIKit

/// 플래너의 "주간" — Gradin 주간 뷰를 옮긴 것.
/// 위에 고정된 요일·날짜 줄, 아래는 좌우로 넘기는 그날의 상세.
struct PlannerWeekView: View {
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date
    /// 상단 바의 + 가 눌렸다는 신호. 처리한 뒤 직접 끈다.
    @Binding var addRequested: Bool

    @Query private var allEntries: [TimetableEntry]
    @Query private var allPlanItems: [PlanItem]

    @State private var scrolledDayIndex: Int?
    @State private var isAddingItem = false

    var body: some View {
        VStack(spacing: 0) {
            PlannerWeekdayHeader()
            Divider()
            dateNumbers
            Divider()
            dayPager
        }
        // 주간에는 일간 같은 인라인 입력 줄이 없으므로 폼을 띄운다.
        .sheet(isPresented: $isAddingItem) {
            PlanItemFormView(defaultDate: selectedDate)
        }
        .onChange(of: addRequested) { _, requested in
            guard requested else { return }
            addRequested = false
            isAddingItem = true
        }
        .onAppear {
            if scrolledDayIndex == nil {
                scrolledDayIndex = PlannerDateHelper.dayIndex(for: selectedDate, calendar: calendar)
            }
        }
    }

    // MARK: - 날짜 줄

    private var dateNumbers: some View {
        HStack(spacing: 0) {
            ForEach(PlannerDateHelper.weekDates(containing: selectedDate, calendar: calendar), id: \.self) { day in
                let isToday = calendar.isDateInToday(day)
                let isSelected = PlannerDateHelper.isSameDay(day, selectedDate, calendar: calendar)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDate = PlannerDateHelper.startOfDay(day, calendar: calendar)
                    }
                } label: {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.callout.bold())
                        .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .primary)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle().fill(
                                isSelected ? Color.accentColor
                                    : isToday ? Color.accentColor.opacity(0.12)
                                    : .clear
                            )
                        }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    // MARK: - 좌우 페이징

    private var dayPager: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(pageRange, id: \.self) { index in
                        detail(for: PlannerDateHelper.date(forDayIndex: index, calendar: calendar))
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledDayIndex)
            .scrollIndicators(.hidden)
        }
        .onChange(of: scrolledDayIndex) { _, newValue in
            guard let newValue,
                  newValue != PlannerDateHelper.dayIndex(for: selectedDate, calendar: calendar)
            else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedDate = PlannerDateHelper.date(forDayIndex: newValue, calendar: calendar)
        }
        .onChange(of: selectedDate) { _, newValue in
            let index = PlannerDateHelper.dayIndex(for: newValue, calendar: calendar)
            if scrolledDayIndex != index {
                withAnimation { scrolledDayIndex = index }
            }
        }
    }

    private var pageRange: ClosedRange<Int> {
        let center = PlannerDateHelper.dayIndex(for: Date(), calendar: calendar)
        return (center - 3650)...(center + 3650)
    }

    // MARK: - 그날 상세

    private func entries(on date: Date) -> [TimetableEntry] {
        let weekday = PlannerDateHelper.calendarWeekday(of: date, calendar: calendar)
        return allEntries
            .filter { $0.dayOfWeek == weekday }
            .sorted {
                PlannerDateHelper.minutesOfDay($0.startTime, calendar: calendar)
                    < PlannerDateHelper.minutesOfDay($1.startTime, calendar: calendar)
            }
    }

    private func planItems(on date: Date) -> [PlanItem] {
        allPlanItems
            .filter { PlannerDateHelper.isSameDay($0.date, date, calendar: calendar) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @ViewBuilder
    private func detail(for date: Date) -> some View {
        let entries = entries(on: date)
        let items = planItems(on: date)

        if entries.isEmpty, items.isEmpty {
            VStack {
                Text("이 날은 비어 있어요")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    if !entries.isEmpty {
                        section("시간표") {
                            ForEach(entries, id: \.persistentModelID) { entry in
                                PlannerScheduleCard(entry: entry)
                            }
                        }
                    }
                    if !items.isEmpty {
                        section("할 일") {
                            ForEach(items, id: \.persistentModelID) { item in
                                PlannerTaskCard(
                                    title: item.title,
                                    subtitle: item.relatedSubjectName,
                                    isDone: item.isDone,
                                    onToggle: { item.isDone.toggle() }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private func section<Content: View>(
        _ title: LocalizedStringKey, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 8) {
                content()
            }
        }
    }
}

/// 요일 머리글. 주말 색은 요일 번호로 판단한다 — 첫 요일 설정(일/월 시작)이 바뀌어도
/// 토·일에 정확히 붙는다.
struct PlannerWeekdayHeader: View {
    @Environment(\.calendar) private var calendar

    var body: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekday = calendar.firstWeekday

        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let weekday = (firstWeekday - 1 + index) % 7 + 1
                Text(verbatim: symbols[weekday - 1])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PlannerWeekdayHeader.color(weekday: weekday))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    /// 일요일 빨강 / 토요일 파랑. 이 빨강은 브랜드 accent가 아니라 달력 관습이다.
    static func color(weekday: Int) -> Color {
        weekday == 1 ? .red : weekday == 7 ? .blue : .secondary
    }
}
