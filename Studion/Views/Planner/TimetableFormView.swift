import SwiftUI
import SwiftData

/// 시간표 등록/편집/삭제.
///
/// 자정을 넘기는 일정은 1차 범위에서 지원하지 않으며, 입력 시점에 막고 인라인으로 안내한다.
struct TimetableFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    var editing: TimetableEntry?
    /// 새로 만들 때 기본 선택할 요일 (Calendar 컨벤션).
    var defaultWeekday: Int = 2
    /// 시간표 표의 빈 칸에서 열었을 때 그 교시. 시각을 미리 채운다.
    var defaultPeriodNumber: Int?

    /// 교시 시각은 사용자가 학교에 맞게 고친 일과표를 따른다 (→ `SchoolPeriodSchedule`).
    @AppStorage(PreferenceKey.periodSchedule) private var scheduleJSON = ""

    @State private var displayIndex = 0
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var title = ""
    @State private var location = ""
    @State private var type: TimetableEntryType = .school
    @State private var colorIndex = 0
    /// 사용자가 색을 직접 골랐는지. 고르기 전에는 과목명에 맞춰 자동으로 따라간다.
    @State private var didChooseColor = false
    @State private var repeatsWeekly = true
    @State private var isConfirmingDelete = false

    /// 같은 과목은 같은 색이어야 하므로 이미 있는 수업들의 색을 본다.
    @Query private var allEntries: [TimetableEntry]

    private var schedule: SchoolPeriodSchedule { SchoolPeriodSchedule(json: scheduleJSON) }

    private var isTimeRangeValid: Bool {
        PlannerDateHelper.isValidTimeRange(start: startTime, end: endTime, calendar: calendar)
    }

    private var canSave: Bool {
        !title.trimmed.isEmpty && isTimeRangeValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("과목명 / 학원명", text: $title)

                    TextField("교실 (선택)", text: $location)

                    Picker("유형", selection: $type) {
                        Label("학교", systemImage: "building.columns")
                            .tag(TimetableEntryType.school)
                        Label("학원", systemImage: "book")
                            .tag(TimetableEntryType.academy)
                    }
                } footer: {
                    Text("이동수업이면 교실을 적어두세요 — 시간표에 함께 보입니다. (예: 3-5, 과학실)")
                }

                Section {
                    colorPicker
                } header: {
                    Text("색")
                } footer: {
                    Text("같은 과목명을 쓰면 색이 자동으로 맞춰집니다. 직접 고를 수도 있어요.")
                }

                Section {
                    Picker("요일", selection: $displayIndex) {
                        ForEach(0..<7, id: \.self) { index in
                            Text(weekdayName(displayIndex: index)).tag(index)
                        }
                    }
                    Picker("교시", selection: periodSelection) {
                        Text("직접 입력").tag(Int?.none)
                        ForEach(schedule.periods) { period in
                            Text("\(period.number)교시").tag(Int?.some(period.number))
                        }
                    }
                    DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("종료", selection: $endTime, displayedComponents: .hourAndMinute)
                } footer: {
                    if !isTimeRangeValid {
                        Text("종료 시각이 시작 시각보다 늦어야 합니다. 자정을 넘기는 일정은 아직 지원하지 않습니다.")
                    } else {
                        Text("교시를 고르면 시각이 채워집니다. 학교 일과가 다르면 시간표 화면의 표 설정에서 교시 시각을 맞춰 두세요.")
                    }
                }

                Section {
                    Toggle("매주 반복", isOn: $repeatsWeekly)
                }

                if editing != nil {
                    Section {
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("이 수업 삭제", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "시간표 추가" : "시간표 편집")
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
            .confirmationDialog(
                "이 수업을 삭제할까요?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) { delete() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("시간표에서 사라집니다. 되돌릴 수 없습니다.")
            }
            .onAppear(perform: loadInitialValues)
            .onChange(of: title) { _, newTitle in
                guard !didChooseColor else { return }
                colorIndex = autoColor(for: newTitle)
            }
        }
    }

    /// 색 고르기. 손으로 고르기 전까지는 과목명을 따라간다 — 대부분은 고를 일이 없다.
    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TimetableColorPalette.colors.indices, id: \.self) { index in
                    Button {
                        colorIndex = index
                        didChooseColor = true
                    } label: {
                        Circle()
                            .fill(TimetableColorPalette.color(at: index))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if colorIndex == index {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(index + 1)번 색")
                    .accessibilityAddTraits(colorIndex == index ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// 과목명에 맞는 색을 찾는다. 이미 그 과목이 시간표에 있으면 같은 색을 쓰고,
    /// 없으면 지금 가장 덜 쓰인 색을 준다.
    private func autoColor(for title: String) -> Int {
        let existing = TimetableColorAssigner.existingAssignments(
            from: allEntries
                .filter { $0.persistentModelID != editing?.persistentModelID }
                .map { ($0.title, $0.colorIndex) }
        )
        return TimetableColorAssigner.assign(titles: [title], existing: existing)[
            TimetableColorAssigner.key(for: title)
        ] ?? 0
    }

    /// 교시 선택. 저장되는 값은 어디까지나 **시각**이라, 고른 교시를 따로 들고 있지 않고
    /// 지금 시각과 정확히 맞는 교시를 되짚어 보여준다 — 시각을 손으로 고치면 자연스럽게
    /// "직접 입력"으로 돌아간다.
    private var periodSelection: Binding<Int?> {
        Binding(
            get: { matchingPeriodNumber },
            set: { number in
                guard let number, let period = schedule.period(number: number) else { return }
                startTime = time(atMinutes: period.startMinutes)
                endTime = time(atMinutes: period.endMinutes)
            }
        )
    }

    private var matchingPeriodNumber: Int? {
        let start = PlannerDateHelper.minutesOfDay(startTime, calendar: calendar)
        let end = PlannerDateHelper.minutesOfDay(endTime, calendar: calendar)
        return schedule.periods
            .first { $0.startMinutes == start && $0.endMinutes == end }?
            .number
    }

    private func time(atMinutes minutes: Int) -> Date {
        calendar.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? Date()
    }

    private func weekdayName(displayIndex index: Int) -> String {
        let weekday = PlannerDateHelper.calendarWeekday(forDisplayIndex: index)
        let symbols = calendar.weekdaySymbols
        // weekdaySymbols는 0-based이고 Calendar weekday는 1-based다.
        return symbols[weekday - 1]
    }

    private func loadInitialValues() {
        if let editing {
            displayIndex = PlannerDateHelper.displayIndex(forCalendarWeekday: editing.dayOfWeek)
            startTime = editing.startTime
            endTime = editing.endTime
            title = editing.title
            location = editing.location
            type = editing.type
            colorIndex = editing.colorIndex
            // 이미 저장된 수업은 그 색이 사용자의 선택이다 — 이름을 고쳤다고 바꾸지 않는다.
            didChooseColor = true
            repeatsWeekly = editing.repeatsWeekly
            return
        }

        displayIndex = PlannerDateHelper.displayIndex(forCalendarWeekday: defaultWeekday)
        if let number = defaultPeriodNumber, let period = schedule.period(number: number) {
            startTime = time(atMinutes: period.startMinutes)
            endTime = time(atMinutes: period.endMinutes)
        } else {
            startTime = time(atMinutes: 9 * 60)
            endTime = time(atMinutes: 10 * 60)
        }
    }

    private func save() {
        let weekday = PlannerDateHelper.calendarWeekday(forDisplayIndex: displayIndex)
        let entry = editing ?? TimetableEntry()

        entry.dayOfWeek = weekday
        entry.startTime = startTime
        entry.endTime = endTime
        entry.title = title.trimmed
        entry.location = location.trimmed
        entry.type = type
        entry.colorIndex = colorIndex
        entry.repeatsWeekly = repeatsWeekly

        if editing == nil { context.insert(entry) }
        dismiss()
    }

    private func delete() {
        guard let editing else { return }
        context.delete(editing)
        dismiss()
    }
}
