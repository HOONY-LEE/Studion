import SwiftUI
import SwiftData
import PhotosUI

/// 문제 출제 / 편집.
///
/// 타입을 먼저 고르면 그에 맞는 입력 필드만 나타난다.
/// 쓰지 않는 필드를 화면에 남겨두지 않는 것이 이 화면의 규칙이다.
struct QuestionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let questionSet: QuestionSet
    var editing: Question?

    @State private var type: QuestionType = .flashcard
    @State private var prompt = ""
    @State private var passageText = ""
    @State private var choices: [String] = ["", ""]
    @State private var correctChoiceIndex: Int?
    @State private var answerTexts: [String] = [""]
    @State private var explanation = ""
    @State private var hint = ""

    @State private var questionImageData: Data?
    @State private var explanationImageData: Data?
    @State private var questionPhotoItem: PhotosPickerItem?
    @State private var explanationPhotoItem: PhotosPickerItem?

    /// 선택지 최대 개수. 모델 주석과 설계 문서(§3)가 정한 상한이다.
    private static let maxChoices = 5

    private var trimmedAnswers: [String] {
        answerTexts.map(\.trimmed).filter { !$0.isEmpty }
    }

    private var trimmedChoices: [String] {
        choices.map(\.trimmed).filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        guard !prompt.trimmed.isEmpty else { return false }
        return type.usesChoices ? trimmedChoices.count >= 2 : !trimmedAnswers.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                promptSection
                if type.usesChoices { choicesSection }
                if type.usesTextAnswer { answerSection }
                passageSection
                explanationSection
            }
            .navigationTitle(editing == nil ? "문제 출제" : "문제 편집")
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
            .onChange(of: questionPhotoItem) { _, item in
                Task { questionImageData = await loadImage(item) }
            }
            .onChange(of: explanationPhotoItem) { _, item in
                Task { explanationImageData = await loadImage(item) }
            }
            .onAppear(perform: loadExistingValues)
        }
    }

    // MARK: - 섹션

    private var typeSection: some View {
        Section {
            Picker("문제 유형", selection: $type) {
                ForEach(QuestionType.allCases) { item in
                    Label(item.displayName, systemImage: item.systemImage).tag(item)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("문제 유형")
        } footer: {
            Text(typeHelpText)
        }
    }

    private var typeHelpText: LocalizedStringKey {
        switch type {
        case .flashcard: "앞면을 보고 떠올린 뒤 뒤집어 확인합니다. 앱이 채점하지 않고 본인이 판단합니다."
        case .multipleChoice: "선택지를 2개 이상 입력하세요. 정답을 지정하지 않으면 골라보기만 합니다."
        case .fillInBlank: "빈칸 자리에 밑줄 네 개(____)를 넣으세요."
        case .shortAnswer: "학생이 직접 입력한 답을 채점합니다."
        }
    }

    private var promptSection: some View {
        Section {
            TextField(promptPlaceholder, text: $prompt, axis: .vertical)
                .lineLimit(2...6)

            imagePicker(
                label: questionImageData == nil ? "문제 이미지 추가" : "문제 이미지 바꾸기",
                selection: $questionPhotoItem,
                data: $questionImageData
            )
        } header: {
            Text(type == .flashcard ? "앞면" : "문제")
        } footer: {
            if type == .fillInBlank {
                Text("예: The cat ____ on the mat.")
            }
        }
    }

    private var promptPlaceholder: LocalizedStringKey {
        switch type {
        case .flashcard: "단어 또는 질문"
        case .multipleChoice: "문제를 입력하세요"
        case .fillInBlank: "빈칸(____)이 포함된 문장"
        case .shortAnswer: "문제를 입력하세요"
        }
    }

    private var choicesSection: some View {
        Section {
            ForEach(choices.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Button {
                        // 같은 항목을 다시 누르면 정답 지정을 해제한다.
                        correctChoiceIndex = (correctChoiceIndex == index) ? nil : index
                    } label: {
                        Image(systemName: correctChoiceIndex == index
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(correctChoiceIndex == index
                                             ? Color("GoalAchieved") : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(index + 1)번을 정답으로 지정")

                    TextField("선택지 \(index + 1)", text: $choices[index])
                }
            }
            .onDelete(perform: deleteChoice)

            if choices.count < Self.maxChoices {
                Button {
                    choices.append("")
                } label: {
                    Label("선택지 추가", systemImage: "plus")
                }
            }
        } header: {
            Text("선택지")
        } footer: {
            Text("왼쪽 동그라미를 눌러 정답을 지정하세요. 최대 \(Self.maxChoices)개까지 넣을 수 있습니다.")
        }
    }

    private var answerSection: some View {
        Section {
            ForEach(answerTexts.indices, id: \.self) { index in
                TextField(answerPlaceholder(index), text: $answerTexts[index])
            }
            .onDelete(perform: deleteAnswer)

            Button {
                answerTexts.append("")
            } label: {
                Label("정답 추가", systemImage: "plus")
            }
        } header: {
            Text(type == .flashcard ? "뒷면" : "정답")
        } footer: {
            if type == .flashcard {
                Text("카드를 뒤집으면 보이는 내용입니다.")
            } else {
                Text("여러 개를 넣으면 그중 하나만 맞아도 정답으로 봅니다. 대소문자와 앞뒤 공백은 무시합니다.")
            }
        }
    }

    private func answerPlaceholder(_ index: Int) -> LocalizedStringKey {
        if type == .flashcard {
            return index == 0 ? "뜻 또는 답" : "추가 설명"
        }
        return index == 0 ? "정답" : "다른 표기도 정답으로 인정"
    }

    private var passageSection: some View {
        Section {
            TextField("보기 지문 (선택)", text: $passageText, axis: .vertical)
                .lineLimit(2...8)
        } header: {
            Text("보기")
        } footer: {
            Text("문제와 별개로 딸려오는 글이 있을 때 씁니다.")
        }
    }

    private var explanationSection: some View {
        Section {
            TextField("해설 (선택)", text: $explanation, axis: .vertical)
                .lineLimit(2...6)
            TextField("힌트 (선택)", text: $hint)

            imagePicker(
                label: explanationImageData == nil ? "설명 이미지 추가" : "설명 이미지 바꾸기",
                selection: $explanationPhotoItem,
                data: $explanationImageData
            )
        } header: {
            Text("해설")
        } footer: {
            Text("문제를 푼 뒤에 보여줍니다.")
        }
    }

    @ViewBuilder
    private func imagePicker(
        label: LocalizedStringKey,
        selection: Binding<PhotosPickerItem?>,
        data: Binding<Data?>
    ) -> some View {
        if let imageData = data.wrappedValue, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Button(role: .destructive) {
                data.wrappedValue = nil
            } label: {
                Label("이미지 삭제", systemImage: "trash")
            }
        }

        PhotosPicker(selection: selection, matching: .images) {
            Label(label, systemImage: "photo")
        }
    }

    // MARK: - 동작

    private func loadImage(_ item: PhotosPickerItem?) async -> Data? {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        // 오답노트와 같은 방식으로 저장 전 용량을 줄인다.
        return ImageDownsampler.downsample(data)
    }

    private func deleteChoice(at offsets: IndexSet) {
        // 정답으로 지정된 항목이 사라지거나 인덱스가 밀리면 지정을 해제한다.
        if let index = correctChoiceIndex, offsets.contains(index) {
            correctChoiceIndex = nil
        } else if let index = correctChoiceIndex {
            let removedBefore = offsets.filter { $0 < index }.count
            correctChoiceIndex = index - removedBefore
        }
        choices.remove(atOffsets: offsets)
    }

    private func deleteAnswer(at offsets: IndexSet) {
        answerTexts.remove(atOffsets: offsets)
        if answerTexts.isEmpty { answerTexts = [""] }
    }

    private func loadExistingValues() {
        guard let editing else { return }
        type = editing.type
        prompt = editing.prompt
        passageText = editing.passageText
        choices = editing.choices.isEmpty ? ["", ""] : editing.choices
        correctChoiceIndex = editing.correctChoiceIndex
        answerTexts = editing.acceptedAnswers.isEmpty ? [""] : editing.acceptedAnswers
        explanation = editing.explanation
        hint = editing.hint
        questionImageData = editing.questionImageData
        explanationImageData = editing.explanationImageData
    }

    private func save() {
        let question = editing ?? Question(questionSet: questionSet)

        question.type = type
        question.prompt = prompt.trimmed
        question.passageText = passageText.trimmed
        question.explanation = explanation.trimmed
        question.hint = hint.trimmed
        question.questionImageData = questionImageData
        question.explanationImageData = explanationImageData

        // 타입에 맞지 않는 필드는 비워 둔다 — 타입을 바꿔 저장했을 때 옛 값이 남지 않게 한다.
        if type.usesChoices {
            question.choices = trimmedChoices
            let index = correctChoiceIndex
            question.correctChoiceIndex = (index.map { $0 < trimmedChoices.count } ?? false) ? index : nil
            question.acceptedAnswers = []
        } else {
            question.choices = []
            question.correctChoiceIndex = nil
            question.acceptedAnswers = trimmedAnswers
        }

        if editing == nil {
            question.orderIndex = (questionSet.questions?.count ?? 0)
            question.questionSet = questionSet
            context.insert(question)
        }

        questionSet.touch()
        dismiss()
    }
}
