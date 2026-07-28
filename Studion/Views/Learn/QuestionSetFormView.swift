import SwiftUI
import SwiftData

/// 문제집 만들기 / 편집.
struct QuestionSetFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editing: QuestionSet?

    @State private var title = ""
    @State private var setDescription = ""
    @State private var subjectName = ""

    private var canSave: Bool { !title.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("문제집 이름", text: $title)
                    TextField("과목 (선택)", text: $subjectName)
                } footer: {
                    Text("예: 영단어 Day 1, 수학 미적분 오답")
                }

                Section("설명 (선택)") {
                    TextField("어떤 문제집인지 적어두세요", text: $setDescription, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(editing == nil ? "문제집 만들기" : "문제집 편집")
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
            .onAppear(perform: loadExistingValues)
        }
    }

    private func loadExistingValues() {
        guard let editing else { return }
        title = editing.title
        setDescription = editing.setDescription
        subjectName = editing.subjectName
    }

    private func save() {
        let set = editing ?? QuestionSet()
        set.title = title.trimmed
        set.setDescription = setDescription.trimmed
        set.subjectName = subjectName.trimmed
        set.touch()

        if editing == nil {
            context.insert(set)
        }
        dismiss()
    }
}
