import SwiftUI
import SwiftData

/// 할 일 추가/편집.
struct PlanItemFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    var editing: PlanItem?
    /// 새로 만들 때 기본 날짜.
    var defaultDate: Date = Date()

    @State private var title = ""
    @State private var date = Date()
    @State private var relatedSubjectName = ""

    private var canSave: Bool { !title.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("할 일", text: $title)
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                }

                Section {
                    TextField("과목 (선택)", text: $relatedSubjectName)
                } footer: {
                    Text("과목명을 적어두면 나중에 찾기 쉬워집니다.")
                }
            }
            .navigationTitle(editing == nil ? "할 일 추가" : "할 일 편집")
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
            .onAppear {
                if let editing {
                    title = editing.title
                    date = editing.date
                    relatedSubjectName = editing.relatedSubjectName ?? ""
                } else {
                    date = defaultDate
                }
            }
        }
    }

    private func save() {
        let item = editing ?? PlanItem()
        item.title = title.trimmed
        // 하루 단위로 다루므로 저장 시점에 정규화한다.
        item.date = PlannerDateHelper.startOfDay(date, calendar: calendar)
        let subject = relatedSubjectName.trimmed
        item.relatedSubjectName = subject.isEmpty ? nil : subject

        if editing == nil { context.insert(item) }
        dismiss()
    }
}
