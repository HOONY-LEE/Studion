import SwiftUI
import SwiftData

/// 시간표 등록/편집.
///
/// 자정을 넘기는 일정은 1차 범위에서 지원하지 않으며, 입력 시점에 막고 인라인으로 안내한다.
struct TimetableFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    var editing: TimetableEntry?
    /// 새로 만들 때 기본 선택할 요일 (Calendar 컨벤션).
    var defaultWeekday: Int = 2

    @State private var displayIndex = 0
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var title = ""
    @State private var type: TimetableEntryType = .school
    @State private var repeatsWeekly = true

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

                    Picker("유형", selection: $type) {
                        Label("학교", systemImage: "building.columns")
                            .tag(TimetableEntryType.school)
                        Label("학원", systemImage: "book")
                            .tag(TimetableEntryType.academy)
                    }
                }

                Section {
                    Picker("요일", selection: $displayIndex) {
                        ForEach(0..<7, id: \.self) { index in
                            Text(weekdayName(displayIndex: index)).tag(index)
                        }
                    }
                    DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("종료", selection: $endTime, displayedComponents: .hourAndMinute)
                } footer: {
                    if !isTimeRangeValid {
                        Text("종료 시각이 시작 시각보다 늦어야 합니다. 자정을 넘기는 일정은 아직 지원하지 않습니다.")
                    }
                }

                Section {
                    Toggle("매주 반복", isOn: $repeatsWeekly)
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
            .onAppear(perform: loadInitialValues)
        }
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
            type = editing.type
            repeatsWeekly = editing.repeatsWeekly
        } else {
            displayIndex = PlannerDateHelper.displayIndex(forCalendarWeekday: defaultWeekday)
            startTime = calendar.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
            endTime = calendar.date(from: DateComponents(hour: 10, minute: 0)) ?? Date()
        }
    }

    private func save() {
        let weekday = PlannerDateHelper.calendarWeekday(forDisplayIndex: displayIndex)
        let entry = editing ?? TimetableEntry()

        entry.dayOfWeek = weekday
        entry.startTime = startTime
        entry.endTime = endTime
        entry.title = title.trimmed
        entry.type = type
        entry.repeatsWeekly = repeatsWeekly

        if editing == nil { context.insert(entry) }
        dismiss()
    }
}
