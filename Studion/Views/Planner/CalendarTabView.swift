import SwiftUI

/// 캘린더 탭 — Gradin `CalendarContainerView`와 같은 구성.
/// 유리 알약 상단 바(날짜 · 오늘 · 보기 전환) + 월간/주간 전환.
///
/// 보여주는 것은 **기기의 캘린더 일정**이다. 할 일·시간표는 "오늘 할 일" 탭이 다룬다.
struct CalendarTabView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case month, week

        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .month: "월간"
            case .week: "주간"
            }
        }

        var icon: String {
            switch self {
            case .month: "calendar"
            case .week: "calendar.day.timeline.left"
            }
        }
    }

    @Environment(\.calendar) private var calendar

    @State private var mode: Mode = .month
    @State private var focusedDate = Date()
    @State private var addRequested = false

    // Gradin과 같은 휠 피커 시트.
    @State private var isPickingDate = false
    @State private var pickerYear = 2026
    @State private var pickerMonth = 1
    @State private var pickerDay = 1

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)

            Group {
                switch mode {
                case .month:
                    PlannerMonthView(selectedDate: $focusedDate, addRequested: $addRequested)
                        .transition(.opacity)
                case .week:
                    CalendarWeekView(selectedDate: $focusedDate, addRequested: $addRequested)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
        .background(Color.plannerSurfaceBackground)
        .sheet(isPresented: $isPickingDate) { datePickerSheet }
        .onAppear {
            focusedDate = PlannerDateHelper.startOfDay(focusedDate, calendar: calendar)
        }
    }

    // MARK: - 상단 바

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                loadPickerValues()
                isPickingDate = true
            } label: {
                HStack(spacing: 6) {
                    Text(verbatim: dateButtonText)
                        .font(.system(size: 17, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color(.label))
            }
            .buttonStyle(GlassPillButtonStyle())

            if !isOnToday {
                Button {
                    withAnimation {
                        focusedDate = PlannerDateHelper.startOfDay(Date(), calendar: calendar)
                    }
                } label: {
                    Text("오늘")
                        .font(.system(size: 17))
                        .foregroundStyle(Color(.label))
                }
                .buttonStyle(GlassPillButtonStyle())
            }

            Spacer(minLength: 0)

            Menu {
                Picker("보기", selection: $mode) {
                    ForEach(Mode.allCases) { item in
                        Label(item.label, systemImage: item.icon).tag(item)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .medium))
                    Text(mode.label)
                        .font(.system(size: 17))
                }
                .foregroundStyle(Color(.label))
            }
            .buttonStyle(GlassPillButtonStyle())
            .accessibilityLabel("보기 바꾸기")

            Button {
                addRequested = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(.label))
            }
            .buttonStyle(GlassPillButtonStyle())
            .accessibilityLabel("일정 추가")
        }
    }

    /// 월간에서는 일까지 적지 않는다 — 무슨 날인지 오해를 준다 (Gradin과 같다).
    private var dateButtonText: String {
        switch mode {
        case .month: focusedDate.formatted(.dateTime.year().month())
        case .week: focusedDate.formatted(.dateTime.year().month().day())
        }
    }

    private var isOnToday: Bool {
        PlannerDateHelper.isSameDay(focusedDate, Date(), calendar: calendar)
    }

    // MARK: - 날짜 선택 (휠 피커)

    private var datePickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    isPickingDate = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(width: 46, height: 46)
                        .glassCircle(tint: Color(.secondarySystemFill))
                }
                .accessibilityLabel("닫기")

                Spacer()

                Text("날짜 선택")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Button {
                    applyPickerDate()
                    isPickingDate = false
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .glassCircle(tint: .accentColor)
                }
                .accessibilityLabel("완료")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            HStack(spacing: 0) {
                Picker("연도", selection: $pickerYear) {
                    ForEach(1970...2099, id: \.self) { year in
                        Text(verbatim: String(year)).font(.system(size: 24)).tag(year)
                    }
                }
                .pickerStyle(.wheel)

                Picker("월", selection: $pickerMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(verbatim: monthName(month)).font(.system(size: 24)).tag(month)
                    }
                }
                .pickerStyle(.wheel)

                // 주간은 특정 날을 골라야 그 주로 간다. 월간은 달만 고르면 된다.
                if mode == .week {
                    Picker("일", selection: $pickerDay) {
                        ForEach(1...daysInMonth(year: pickerYear, month: pickerMonth), id: \.self) { day in
                            Text(verbatim: "\(day)").font(.system(size: 24)).tag(day)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 16)
            .onChange(of: pickerYear) { _, _ in clampPickerDay() }
            .onChange(of: pickerMonth) { _, _ in clampPickerDay() }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
    }

    private func monthName(_ month: Int) -> String {
        let symbols = calendar.standaloneMonthSymbols
        guard month >= 1, month <= symbols.count else { return "\(month)" }
        return symbols[month - 1]
    }

    private func daysInMonth(year: Int, month: Int) -> Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    private func loadPickerValues() {
        let parts = calendar.dateComponents([.year, .month, .day], from: focusedDate)
        pickerYear = parts.year ?? 2026
        pickerMonth = parts.month ?? 1
        pickerDay = parts.day ?? 1
    }

    /// 31일에서 2월로 넘기면 없는 날이 된다 — 그 달의 마지막 날로 당긴다.
    private func clampPickerDay() {
        let maxDay = daysInMonth(year: pickerYear, month: pickerMonth)
        if pickerDay > maxDay { pickerDay = maxDay }
    }

    private func applyPickerDate() {
        let day = mode == .week ? min(pickerDay, daysInMonth(year: pickerYear, month: pickerMonth)) : 1
        guard let date = calendar.date(
            from: DateComponents(year: pickerYear, month: pickerMonth, day: day)
        ) else { return }
        focusedDate = PlannerDateHelper.startOfDay(date, calendar: calendar)
    }
}
