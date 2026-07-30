import SwiftUI
import UIKit

/// 플래너의 "월간" — **시스템 캘린더(iCloud 등) 일정**을 보여준다.
///
/// 일간·주간이 다루는 할 일·시간표와는 **다른 데이터**다. 월간은 캘린더 앱과 같은 일정을
/// 그대로 비추고, 여기서 추가·수정한 일정도 기기 캘린더에 저장된다
/// (→ `docs/03-domain-logic.md`, 권한 문구는 `project.yml`).
struct PlannerMonthView: View {
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date
    /// 상단 바의 + 가 눌렸다는 신호. 처리한 뒤 직접 끈다.
    @Binding var addRequested: Bool

    @State private var store = CalendarEventStore()
    @State private var selectedMonthIndex =
        PlannerDateHelper.monthIndex(for: Date(), calendar: .current)
    @State private var anchorDate = Date()
    @State private var editingEvent: CalendarEvent?
    @State private var isCreatingEvent = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch store.access {
            case .notDetermined:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .denied:
                accessDenied
            case .granted:
                monthPager
            }
        }
        .task {
            await store.requestAccess()
            await store.loadMonth(containing: selectedDate, calendar: calendar)
        }
        // 다른 앱에서 일정을 바꾸면 알림이 온다 — 돌아왔을 때 옛 내용이 남지 않게 다시 읽는다.
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
        .alert("문제가 발생했어요", isPresented: errorBinding) {
            Button("확인") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: addRequested) { _, requested in
            guard requested else { return }
            addRequested = false
            // 넣을 수 있는 캘린더가 없으면(모두 읽기 전용) 폼을 열어봐야 저장이 안 된다.
            guard store.access == .granted, store.canCreateEvents else { return }
            isCreatingEvent = true
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    /// 권한이 없으면 달력을 채울 수 없다. 무엇이 막혔고 어디서 푸는지 알려준다.
    private var accessDenied: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("캘린더 접근이 꺼져 있어요")
                .font(.headline)
            Text("월간 보기는 기기의 캘린더 일정을 보여줍니다. 설정에서 캘린더 접근을 켜주세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("설정 열기") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 달 넘기기

    /// 좌우로 넘겨 달을 옮긴다 (페이징 방식의 이유는 PlannerTodayView와 같다).
    private var monthPager: some View {
        TabView(selection: $selectedMonthIndex) {
            ForEach(pageRange, id: \.self) { index in
                monthPage(monthIndex: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: selectedMonthIndex) { _, newValue in
            guard newValue != PlannerDateHelper.monthIndex(for: selectedDate, calendar: calendar)
            else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // 넘긴 달이 이번 달이면 오늘로, 아니면 그 달 1일로 맞춘다.
            let monthStart = PlannerDateHelper.monthStart(forMonthIndex: newValue, calendar: calendar)
            let today = PlannerDateHelper.startOfDay(Date(), calendar: calendar)
            selectedDate = calendar.isDate(today, equalTo: monthStart, toGranularity: .month)
                ? today
                : monthStart

            Task { await store.loadMonth(containing: monthStart, calendar: calendar) }
        }
        .onChange(of: selectedDate) { _, newValue in
            let index = PlannerDateHelper.monthIndex(for: newValue, calendar: calendar)
            if selectedMonthIndex != index { selectedMonthIndex = index }
            let center = PlannerDateHelper.monthIndex(for: anchorDate, calendar: calendar)
            if abs(index - center) > Self.pageRadius - 3 {
                anchorDate = newValue
            }
        }
    }

    /// 앞뒤로 둘 달 수.
    private static let pageRadius = 36

    private var pageRange: ClosedRange<Int> {
        let center = PlannerDateHelper.monthIndex(for: anchorDate, calendar: calendar)
        return (center - Self.pageRadius)...(center + Self.pageRadius)
    }

    // MARK: - 한 달

    private func monthPage(monthIndex: Int) -> some View {
        let monthStart = PlannerDateHelper.monthStart(forMonthIndex: monthIndex, calendar: calendar)
        let days = PlannerDateHelper.monthGridDates(for: monthStart, calendar: calendar)
        let rowCount = max(days.count / 7, 1)

        return VStack(spacing: 0) {
            HStack {
                // 연도는 상단 날짜 알약이 이미 보여주므로 큰 제목은 달만.
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
        .task(id: monthIndex) {
            await store.loadMonth(containing: monthStart, calendar: calendar)
        }
    }

    private func dayCell(_ day: Date, monthStart: Date, rowHeight: CGFloat) -> some View {
        let isCurrentMonth = calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let isSelected = PlannerDateHelper.isSameDay(day, selectedDate, calendar: calendar)
        let weekday = calendar.component(.weekday, from: day)
        let events = store.events(on: day)
        let maxBars = max(0, Int((rowHeight - 38) / 17))
        let overflow = events.count - maxBars
        let visible = overflow > 0 ? max(maxBars - 1, 0) : events.count

        return VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(numberColor(isToday: isToday, isCurrentMonth: isCurrentMonth,
                                             weekday: weekday))
                .frame(width: 28, height: 28)
                .background {
                    if isToday {
                        Circle().fill(Color.accentColor)
                    } else if isSelected {
                        Circle().fill(Color.accentColor.opacity(0.15))
                    }
                }
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 1) {
                ForEach(events.prefix(visible)) { event in
                    Button {
                        // 읽기 전용 일정(공휴일 등)은 편집 화면을 열지 않는다.
                        guard event.isEditable else { return }
                        editingEvent = event
                    } label: {
                        Text(verbatim: event.title)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(event.color)
                            .padding(.horizontal, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(event.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                }
                if overflow > 0 {
                    Text(verbatim: "+\(events.count - visible)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .opacity(isCurrentMonth ? 1 : 0.3)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = PlannerDateHelper.startOfDay(day, calendar: calendar)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cellLabel(day, isToday: isToday, eventCount: events.count))
    }

    private func numberColor(isToday: Bool, isCurrentMonth: Bool, weekday: Int) -> Color {
        if isToday { return .white }
        guard isCurrentMonth else { return .secondary }
        let weekendColor = PlannerWeekdayHeader.color(weekday: weekday)
        return weekendColor == .secondary ? .primary : weekendColor
    }

    private func cellLabel(_ day: Date, isToday: Bool, eventCount: Int) -> String {
        var parts = [day.formatted(.dateTime.month().day().weekday(.wide))]
        if isToday { parts.append(String(localized: "오늘")) }
        if eventCount > 0 { parts.append("일정 \(eventCount)개") }
        return parts.joined(separator: ", ")
    }
}

/// 일정 추가·수정. 반복 일정은 이 발생만 고친다 (→ `CalendarEventStore.save`).
struct CalendarEventFormView: View {
    let store: CalendarEventStore
    let editing: CalendarEvent?
    let defaultDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    @State private var title = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var isAllDay = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    private var canSave: Bool { !title.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("제목", text: $title)
                    Toggle("종일", isOn: $isAllDay)
                    DatePicker("시작", selection: $start,
                               displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    DatePicker("종료", selection: $end,
                               displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                } footer: {
                    if end < start {
                        Text("종료가 시작보다 빠릅니다. 저장하면 시작 시각으로 맞춰집니다.")
                    }
                }

                if editing != nil {
                    Section {
                        Button("일정 삭제", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "일정 추가" : "일정 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("일정을 삭제할까요?", isPresented: $isConfirmingDelete) {
                Button("삭제", role: .destructive) { performDelete() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("삭제한 일정은 되돌릴 수 없어요.")
            }
            .alert("문제가 발생했어요", isPresented: errorBinding) {
                Button("확인") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func loadInitialValues() {
        if let editing {
            title = editing.title
            start = editing.start
            end = editing.end
            isAllDay = editing.isAllDay
        } else {
            // 새 일정은 고른 날짜의 다음 정시부터 한 시간으로 잡는다.
            let base = PlannerDateHelper.startOfDay(defaultDate, calendar: calendar)
            let hour = calendar.component(.hour, from: Date()) + 1
            start = calendar.date(bySettingHour: min(hour, 23), minute: 0, second: 0, of: base) ?? base
            end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
        }
    }

    private func save() {
        do {
            try store.save(
                title: title.trimmed, start: start, end: end, isAllDay: isAllDay,
                editing: editing?.eventIdentifier, calendar: calendar
            )
            Task { await store.reload(around: start, calendar: calendar) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performDelete() {
        guard let identifier = editing?.eventIdentifier else { return }
        do {
            try store.delete(identifier: identifier)
            Task { await store.reload(around: editing?.start ?? defaultDate, calendar: calendar) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
