import SwiftUI
import UIKit

/// 캘린더 탭의 "주간" — Gradin `WeekCalendarView`와 같은 구성.
/// 고정된 요일·날짜 줄 + 좌우로 넘기는 그날의 일정 목록.
///
/// 캘린더 탭이므로 **기기의 캘린더 일정**만 보여준다.
struct CalendarWeekView: View {
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date
    @Binding var addRequested: Bool

    @State private var store = CalendarEventStore()
    @State private var selectedDayIndex =
        PlannerDateHelper.dayIndex(for: Date(), calendar: .current)
    @State private var anchorDate = Calendar.current.startOfDay(for: Date())
    @State private var editingEvent: CalendarEvent?
    @State private var isCreatingEvent = false

    var body: some View {
        VStack(spacing: 0) {
            PlannerWeekdayHeader()
            Divider()
            dateNumbers
            Divider()
            dayPager
        }
        .task {
            await store.requestAccess()
            await store.loadMonth(containing: selectedDate, calendar: calendar)
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                await store.reload(around: selectedDate, calendar: calendar)
            }
        }
        .sheet(item: $editingEvent) { event in
            CalendarEventFormView(store: store, editing: event, defaultDate: selectedDate)
        }
        .sheet(isPresented: $isCreatingEvent) {
            CalendarEventFormView(store: store, editing: nil, defaultDate: selectedDate)
        }
        .onChange(of: addRequested) { _, requested in
            guard requested else { return }
            addRequested = false
            guard store.access == .granted, store.canCreateEvents else { return }
            isCreatingEvent = true
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

    /// 좌우로 넘겨 날짜를 옮긴다. `scrollPosition`이 아니라 TabView 페이지 스타일을
    /// 쓰는 이유는 PlannerTodayView와 같다 — 스크롤 위치로 맞추면 아직 만들지 않은
    /// 페이지의 크기를 추정해 옆 페이지에 가서 선다.
    private var dayPager: some View {
        TabView(selection: $selectedDayIndex) {
            ForEach(pageRange, id: \.self) { index in
                detail(for: PlannerDateHelper.date(forDayIndex: index, calendar: calendar))
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: selectedDayIndex) { _, newValue in
            let date = PlannerDateHelper.date(forDayIndex: newValue, calendar: calendar)
            guard !PlannerDateHelper.isSameDay(date, selectedDate, calendar: calendar) else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedDate = date
            Task { await store.loadMonth(containing: date, calendar: calendar) }
        }
        .onChange(of: selectedDate) { _, newValue in
            let index = PlannerDateHelper.dayIndex(for: newValue, calendar: calendar)
            if selectedDayIndex != index { selectedDayIndex = index }
            recenterIfNeeded(around: newValue)
        }
    }

    /// 고른 날짜가 범위 가장자리에 가까우면 그 날짜를 중심으로 다시 잡는다.
    private func recenterIfNeeded(around date: Date) {
        let index = PlannerDateHelper.dayIndex(for: date, calendar: calendar)
        let center = PlannerDateHelper.dayIndex(for: anchorDate, calendar: calendar)
        guard abs(index - center) > Self.pageRadius - 7 else { return }
        anchorDate = PlannerDateHelper.startOfDay(date, calendar: calendar)
    }

    private static let pageRadius = 60

    private var pageRange: ClosedRange<Int> {
        let center = PlannerDateHelper.dayIndex(for: anchorDate, calendar: calendar)
        return (center - Self.pageRadius)...(center + Self.pageRadius)
    }

    // MARK: - 그날 상세

    @ViewBuilder
    private func detail(for day: Date) -> some View {
        let events = store.events(on: day)

        if events.isEmpty {
            VStack {
                Text("일정이 없습니다")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { await store.loadMonth(containing: day, calendar: calendar) }
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        Button {
                            guard event.isEditable else { return }
                            editingEvent = event
                        } label: {
                            row(event)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .task { await store.loadMonth(containing: day, calendar: calendar) }
        }
    }

    private func row(_ event: CalendarEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: event.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(verbatim: event.isAllDay
                     ? String(localized: "종일")
                     : event.start.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassCard()
    }
}
