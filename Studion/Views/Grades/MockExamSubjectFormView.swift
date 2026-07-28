import SwiftUI
import SwiftData

/// 모의고사 과목 성적 입력.
///
/// 원점수·표준점수·백분위·등급을 **전부 사용자가 직접 입력**하며 모두 옵셔널이다.
/// 앱은 네 값을 서로 환산하지 않고, 등급컷을 추정해 빈 칸을 채우지 않는다.
struct MockExamSubjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: MockExamSession
    var editing: MockExamSubjectRecord?

    @State private var subjectName = ""
    @State private var rawScoreText = ""
    @State private var standardScoreText = ""
    @State private var percentileText = ""
    @State private var grade: Int?

    private var canSave: Bool { !subjectName.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("과목명", text: $subjectName)
                }

                Section {
                    numberField("원점수", text: $rawScoreText)
                    numberField("표준점수", text: $standardScoreText)
                    numberField("백분위", text: $percentileText)

                    // 모의고사(수능)는 항상 9등급제다. 내신 등급제 설정과 무관하다.
                    Picker("등급", selection: $grade) {
                        Text("선택 안 함").tag(Int?.none)
                        ForEach(1...9, id: \.self) { value in
                            Text("\(value)등급").tag(Int?.some(value))
                        }
                    }
                } header: {
                    Text("성적")
                } footer: {
                    Text("아는 값만 입력해도 됩니다. 앱이 나머지를 계산하거나 추정하지 않습니다.")
                }
            }
            .navigationTitle(editing == nil ? "과목 추가" : "과목 편집")
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

    /// `LabeledContent` 대신 `HStack`을 쓰는 이유는 `SubjectFormView`와 같다 —
    /// 빈 `TextField`의 탭 영역이 최소 터치 타깃보다 좁아지는 것을 막는다.
    private func numberField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            TextField("선택", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func loadExistingValues() {
        guard let editing else { return }
        subjectName = editing.subjectName
        rawScoreText = editing.rawScore.map(formatted) ?? ""
        standardScoreText = editing.standardScore.map(formatted) ?? ""
        percentileText = editing.percentile.map(formatted) ?? ""
        grade = editing.grade
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private func save() {
        let record = editing ?? MockExamSubjectRecord(session: session)

        record.subjectName = subjectName.trimmed
        record.rawScore = Double(rawScoreText.trimmed)
        record.standardScore = Double(standardScoreText.trimmed)
        record.percentile = Double(percentileText.trimmed)
        record.grade = grade

        if editing == nil {
            record.session = session
            context.insert(record)
        }
        dismiss()
    }
}
