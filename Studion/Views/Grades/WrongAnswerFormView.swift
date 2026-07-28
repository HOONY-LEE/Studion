import SwiftUI
import SwiftData
import PhotosUI

/// 오답노트 생성/편집.
///
/// 흐름: 사진 선택 → OCR → **텍스트 확인·수정(건너뛸 수 없음)** → 원인 태그 → (영어) 하위 카테고리 → 저장
///
/// OCR은 틀린다. 추출된 텍스트를 사용자가 확인하지 않고 저장하는 경로를 만들지 않는다.
private struct CropTarget: Identifiable {
    let id = UUID()
    let image: UIImage
}

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
    @State private var userEditedText = ""
    @State private var causeTag: WrongAnswerCauseTag = .dontKnow
    @State private var englishSubcategory: EnglishSubcategory?

    @State private var isMultipleChoiceEnabled = false
    @State private var correctChoiceIndex: Int?

    /// 선택지는 저장하지 않고 그때그때 다시 뽑는다 — 텍스트를 고쳐도 미리보기가 항상 최신이다.
    private var parsedChoices: MultipleChoiceParser.Result? {
        MultipleChoiceParser.parse(userEditedText)
    }

    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isRecognizing = false
    @State private var recognitionFailed = false
    /// 자르기 화면에 넘길 이미지. 값이 생기면 크롭 화면이 뜬다.
    @State private var cropTarget: CropTarget?

    private var canSave: Bool { !userEditedText.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                textSection
                multipleChoiceSection
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
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { data in
                    if let image = UIImage(data: data) {
                        cropTarget = CropTarget(image: image)
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
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

    private var textSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if userEditedText.isEmpty {
                    Text("예: 위 도형에서 각도 x를 구하는 문제")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $userEditedText)
                    .frame(minHeight: 120)
                    .accessibilityLabel("문제 내용")
                    .onChange(of: userEditedText) { _, _ in
                        // 편집으로 선택지 수가 줄어 예전에 고른 정답 인덱스가 범위를 벗어나면 되돌린다.
                        if let index = correctChoiceIndex,
                           let choices = parsedChoices,
                           index >= choices.choices.count {
                            correctChoiceIndex = nil
                        }
                    }
            }
        } header: {
            Text("문제 내용")
        } footer: {
            Text("사진에서 읽은 글자입니다. 도형·그래프 문제라면 사진이 내용을 대신하니 짧게만 적어도 됩니다.")
        }
    }

    @ViewBuilder
    private var multipleChoiceSection: some View {
        if let parsed = parsedChoices {
            Section {
                Toggle("객관식 카드로 저장", isOn: $isMultipleChoiceEnabled)

                if isMultipleChoiceEnabled {
                    ForEach(Array(parsed.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            correctChoiceIndex = (correctChoiceIndex == index) ? nil : index
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text(verbatim: String(MultipleChoiceParser.choiceMarkers[index]))
                                    .fontWeight(.semibold)
                                Text(verbatim: choice)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if correctChoiceIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color("GoalAchieved"))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    }
                }
            } header: {
                Text("객관식으로 인식됨")
            } footer: {
                if isMultipleChoiceEnabled {
                    Text("정답인 보기를 선택해 두면 복습할 때 바로 채점됩니다. 몰라도 괜찮습니다 — 비워두면 채점 없이 골라보기만 합니다.")
                } else {
                    Text("선택지처럼 보이는 부분을 찾았습니다. 서술형으로 저장하려면 꺼둔 채로 두세요.")
                }
            }
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
            } else if userEditedText.trimmed.isEmpty {
                // 사용자가 이미 고쳐 쓴 내용이 있으면 덮어쓰지 않는다.
                userEditedText = text
                // 방금 채운 텍스트가 객관식으로 보이면 기본으로 켜둔다.
                // 이후 사용자가 직접 끄고 켜는 것은 존중하고, 타이핑할 때마다 되돌리지 않는다.
                if MultipleChoiceParser.parse(text) != nil {
                    isMultipleChoiceEnabled = true
                }
            }
        } catch {
            recognitionFailed = true
        }
    }

    private func loadExistingValues() {
        guard let editing else { return }
        imageData = editing.imageData
        ocrRawText = editing.ocrRawText
        userEditedText = editing.userEditedText
        causeTag = editing.causeTag
        englishSubcategory = editing.englishSubcategory
        isMultipleChoiceEnabled = editing.isMultipleChoice
        correctChoiceIndex = editing.correctChoiceIndex
    }

    private func save() {
        let note = editing ?? WrongAnswerNote()

        note.ocrRawText = ocrRawText          // 원본은 보존한다
        note.userEditedText = userEditedText.trimmed
        note.causeTag = causeTag
        note.englishSubcategory = englishSubcategory
        note.imageData = imageData

        let choices = parsedChoices
        let isConfirmedMultipleChoice = isMultipleChoiceEnabled && choices != nil
        note.isMultipleChoice = isConfirmedMultipleChoice

        // 텍스트를 고쳐 선택지 수가 줄었는데 예전 인덱스가 남아있는 경우를 방지한다.
        if let index = correctChoiceIndex, let choices, index < choices.choices.count {
            note.correctChoiceIndex = isConfirmedMultipleChoice ? index : nil
        } else {
            note.correctChoiceIndex = nil
        }

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
