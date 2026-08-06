import SwiftUI
import SwiftData
import PhotosUI

/// 자르기 화면에 넘길 이미지.
private struct CropTarget: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 오답노트 생성/편집.
///
/// 흐름: 사진 선택 → OCR → **나뉜 칸 확인·수정(건너뛸 수 없음)** → 원인 태그 → (영어) 하위 카테고리 → 저장
///
/// 입력 칸은 문제 출제 화면(`QuestionFormView`)과 같은 모양이다 — 지문 / 문제 / 선택지 / 해설.
/// OCR로 읽은 글자를 `OCRQuestionSplitter`가 이 칸들에 나눠 담는다.
///
/// **나눔은 제안일 뿐이다.** OCR도 나눔도 틀리므로, 확인하지 않고 저장하는 경로를 만들지 않고
/// 모든 칸을 손으로 고칠 수 있게 둔다.
struct WrongAnswerFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    /// 내신 과목과 모의고사 과목 중 정확히 하나만 전달한다.
    var schoolSubject: SchoolSubjectRecord?
    var mockExamSubject: MockExamSubjectRecord?
    var editing: WrongAnswerNote?

    @State private var imageData: Data?
    @State private var ocrRawText = ""
    @State private var passageText = ""
    @State private var promptText = ""
    @State private var choices: [String] = []
    @State private var correctChoiceIndex: Int?
    @State private var explanation = ""
    @State private var causeTag: WrongAnswerCauseTag = .dontKnow
    @State private var englishSubcategory: EnglishSubcategory?

    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    /// 촬영은 됐지만 아직 자르기 화면으로 넘기지 않은 사진.
    @State private var capturedImage: UIImage?
    @State private var isRecognizing = false
    @State private var recognitionFailed = false
    /// 자르기 화면에 넘길 이미지. 값이 생기면 크롭 화면이 뜬다.
    @State private var cropTarget: CropTarget?

    /// 화면에 표시할 수 있는 선택지 수의 상한. 원문자 표시가 ⑩까지만 있다.
    private static var maxChoices: Int { MultipleChoiceParser.choiceMarkers.count }

    /// 저장할 선택지와, 그 배열 기준으로 옮긴 정답 인덱스.
    ///
    /// 빈 칸은 버리는데, 버린 칸이 정답보다 앞에 있으면 인덱스가 밀린다. 그대로 저장하면
    /// **엉뚱한 보기가 정답이 된다** — 그래서 거르면서 인덱스를 같이 옮긴다.
    private var savedChoices: (choices: [String], correctIndex: Int?) {
        var kept: [String] = []
        var correctIndex: Int?
        for (index, raw) in choices.enumerated() {
            let trimmed = raw.trimmed
            guard !trimmed.isEmpty else { continue }
            if correctChoiceIndex == index { correctIndex = kept.count }
            kept.append(trimmed)
        }
        return (kept, correctIndex)
    }

    /// 사진만 있고 글자가 거의 없는 도형 문제도 저장할 수 있어야 하므로 문제 칸 하나만 요구한다.
    private var canSave: Bool { !promptText.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                passageSection
                promptSection
                choicesSection
                explanationSection
                causeSection
                englishSection
            }
            .navigationTitle(editing == nil ? "오답노트 추가" : "오답노트 편집")
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
            // 촬영본은 카메라가 **닫힌 뒤에** 자르기 화면으로 넘긴다. 시트가 닫히는 도중에
            // 전체 화면을 띄우면 그 화면이 뜨지 않고 사라져 사진을 통째로 잃는다.
            .sheet(isPresented: $isShowingCamera, onDismiss: presentPendingCrop) {
                CameraPicker { data in
                    capturedImage = UIImage(data: data)
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    // 같은 사진을 다시 고를 수 있게 선택을 비워 둔다 — 값이 그대로면
                    // `onChange`가 울리지 않아 두 번째 선택이 먹히지 않는다.
                    photoItem = nil
                    if let data, let image = UIImage(data: data) {
                        cropTarget = CropTarget(image: image)
                    }
                }
            }
            .fullScreenCover(item: $cropTarget) { target in
                PhotoCropView(
                    image: target.image,
                    onCrop: { cropped in
                        cropTarget = nil
                        Task { await handlePicked(cropped) }
                    },
                    onCancel: { cropTarget = nil }
                )
            }
            .onAppear(perform: loadExistingValues)
        }
    }

    // MARK: - 섹션

    @ViewBuilder
    private var imageSection: some View {
        Section {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("오답 문제 사진")

                Button {
                    cropTarget = CropTarget(image: uiImage)
                } label: {
                    Label("다시 자르기", systemImage: "crop")
                }
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(imageData == nil ? "사진 선택" : "사진 바꾸기", systemImage: "photo")
            }

            if CameraPicker.isAvailable {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("사진 촬영", systemImage: "camera")
                }
            }
        } header: {
            Text("사진")
        } footer: {
            if isRecognizing {
                Label("텍스트를 읽는 중…", systemImage: "text.viewfinder")
            } else if recognitionFailed {
                // "실패"라고 말하지 않는다 — 도형·그래프처럼 글자가 원래 적은 문제일 수 있다.
                // 얼럿 대신 안내 후 직접 입력으로 자연스럽게 이어진다.
                Text("글자를 많이 찾지 못했어요. 도형이나 그래프 문제라면 아래에 짧은 설명만 적어도 충분합니다.")
            } else {
                Text("사진은 기기 안에서만 분석됩니다. 외부로 전송되지 않습니다.")
            }
        }
    }

    private var passageSection: some View {
        Section {
            TextField("보기 지문 (선택)", text: $passageText, axis: .vertical)
                .lineLimit(2...8)
        } header: {
            Text("지문")
        } footer: {
            Text("문제와 별개로 딸려오는 글이 있을 때 씁니다. 없으면 비워두세요.")
        }
    }

    private var promptSection: some View {
        Section {
            TextField("예: 위 도형에서 각도 x를 구하는 문제", text: $promptText, axis: .vertical)
                .lineLimit(2...8)
                .accessibilityLabel("문제")
        } header: {
            Text("문제")
        } footer: {
            Text("사진에서 읽은 글자를 칸마다 나눠 담았습니다. 잘못 나뉘었으면 옮겨 적어 주세요. 도형·그래프 문제라면 사진이 내용을 대신하니 짧게만 적어도 됩니다.")
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

                    TextField("선택지 \(index + 1)", text: $choices[index], axis: .vertical)
                        .lineLimit(1...4)
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
            if choices.isEmpty {
                Text("서술형 문제라면 비워두세요. 2개 이상 넣으면 복습할 때 골라보는 카드가 됩니다.")
            } else {
                Text("왼쪽 동그라미를 눌러 정답을 지정하세요. 몰라도 괜찮습니다 — 비워두면 채점 없이 골라보기만 합니다.")
            }
        }
    }

    private var explanationSection: some View {
        Section {
            TextField("해설 (선택)", text: $explanation, axis: .vertical)
                .lineLimit(2...6)
        } header: {
            Text("해설")
        } footer: {
            Text("복습할 때 내용과 함께 보여줍니다.")
        }
    }

    private var causeSection: some View {
        Section("틀린 이유") {
            Picker("틀린 이유", selection: $causeTag) {
                ForEach(WrongAnswerCauseTag.allCases) { tag in
                    Text(tag.displayName).tag(tag)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var englishSection: some View {
        Section {
            Picker("영역", selection: $englishSubcategory) {
                Text("선택 안 함").tag(EnglishSubcategory?.none)
                ForEach(EnglishSubcategory.allCases) { item in
                    Text(item.displayName).tag(EnglishSubcategory?.some(item))
                }
            }
        } header: {
            Text("영어 영역 (선택)")
        } footer: {
            Text("영어 과목이라면 영역을 지정해 두면 나중에 걸러 볼 수 있습니다.")
        }
    }

    // MARK: - 동작

    private func handlePicked(_ data: Data) async {
        let compressed = ImageDownsampler.downsample(data)
        imageData = compressed
        recognitionFailed = false
        isRecognizing = true
        defer { isRecognizing = false }

        do {
            let text = try await TextRecognizer.recognizeText(in: compressed)
            ocrRawText = text
            if text.trimmed.isEmpty {
                recognitionFailed = true
            } else if promptText.trimmed.isEmpty && passageText.trimmed.isEmpty && choices.isEmpty {
                // 사용자가 이미 고쳐 쓴 내용이 있으면 덮어쓰지 않는다.
                apply(OCRQuestionSplitter.split(text))
            }
        } catch {
            recognitionFailed = true
        }
    }

    private func presentPendingCrop() {
        guard let capturedImage else { return }
        self.capturedImage = nil
        cropTarget = CropTarget(image: capturedImage)
    }

    private func apply(_ split: OCRQuestionSplitter.Result) {
        passageText = split.passage
        promptText = split.prompt
        choices = split.choices
        // 정답은 앱이 추정하지 않는다 — 항상 비워둔 채로 시작한다.
        correctChoiceIndex = nil
    }

    /// 선택지 칸을 지운다. 정답 지정이 엉뚱한 항목으로 밀리지 않게 함께 손본다.
    private func deleteChoice(at offsets: IndexSet) {
        if let index = correctChoiceIndex, offsets.contains(index) {
            correctChoiceIndex = nil
        } else if let index = correctChoiceIndex {
            correctChoiceIndex = index - offsets.filter { $0 < index }.count
        }
        choices.remove(atOffsets: offsets)
    }

    private func loadExistingValues() {
        guard let editing else { return }
        imageData = editing.imageData
        ocrRawText = editing.ocrRawText
        causeTag = editing.causeTag
        englishSubcategory = editing.englishSubcategory
        explanation = editing.explanation
        correctChoiceIndex = editing.correctChoiceIndex

        // 옛 노트는 `content`가 저장된 한 덩어리 텍스트를 나눠 돌려준다.
        let content = editing.content
        passageText = content.passage
        promptText = content.prompt
        choices = content.choices
    }

    private func save() {
        let note = editing ?? WrongAnswerNote()

        let saved = savedChoices
        let content = OCRQuestionSplitter.Result(
            passage: passageText.trimmed,
            prompt: promptText.trimmed,
            // 선택지가 하나뿐이면 객관식이 아니다. 남겨두면 보기 하나짜리 카드가 된다.
            choices: saved.choices.count >= 2 ? saved.choices : []
        )

        note.ocrRawText = ocrRawText          // 원본은 보존한다
        note.passageText = content.passage
        note.promptText = content.prompt
        note.choices = content.choices
        note.explanation = explanation.trimmed
        // 목록 미리보기와 백업이 쓰는 통짜 텍스트. 구조화 필드로부터 다시 만들어 어긋나지 않게 한다.
        note.userEditedText = content.combinedText
        note.causeTag = causeTag
        note.englishSubcategory = englishSubcategory
        note.imageData = imageData

        note.isMultipleChoice = content.isMultipleChoice
        note.correctChoiceIndex = content.isMultipleChoice ? saved.correctIndex : nil

        if editing == nil {
            // 둘 다 받는 생성 경로를 만들지 않는다 — 정확히 하나만 연결한다.
            if let schoolSubject {
                note.schoolSubject = schoolSubject
            } else if let mockExamSubject {
                note.mockExamSubject = mockExamSubject
            }

            let schedule = ReviewScheduler.initialSchedule(createdAt: Date(), calendar: calendar)
            note.leitnerBoxIndex = schedule.boxIndex
            note.nextReviewDate = schedule.nextReviewDate

            context.insert(note)
        }

        dismiss()
    }
}
