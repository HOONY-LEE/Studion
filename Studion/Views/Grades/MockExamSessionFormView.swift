import SwiftUI
import SwiftData

/// 모의고사 회차 추가/편집.
///
/// 회차명은 **항상 사용자 자유 입력**이다 — 앱이 시행 목록을 내장하지 않는다.
struct MockExamSessionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var editing: MockExamSession?

    @State private var name = ""
    @State private var examDate = Date()

    private var canSave: Bool { !name.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("회차명", text: $name)
                    DatePicker("시험일", selection: $examDate, displayedComponents: .date)
                } footer: {
                    Text("예: 2026년 6월 학평")
                }
            }
            .navigationTitle(editing == nil ? "회차 추가" : "회차 편집")
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
                guard let editing else { return }
                name = editing.name
                examDate = editing.examDate
            }
        }
    }

    private func save() {
        if let editing {
            editing.name = name.trimmed
            editing.examDate = examDate
        } else {
            context.insert(MockExamSession(name: name.trimmed, examDate: examDate))
        }
        dismiss()
    }
}
