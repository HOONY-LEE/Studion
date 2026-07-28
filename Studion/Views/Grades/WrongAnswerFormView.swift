import SwiftUI
import SwiftData
import PhotosUI

/// 오답노트 생성/편집.
///
/// 흐름: 사진 선택 → OCR → **텍스트 확인·수정(건너뛸 수 없음)** → 원인 태그 → (영어) 하위 카테고리 → 저장
///
/// OCR은 틀린다. 추출된 텍스트를 사용자가 확인하지 않고 저장하는 경로를 만들지 않는다.
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

    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isRecognizing = false
    @State private var recognitionFailed = false

    private var canSave: Bool { !userEditedText.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                textSection
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
                    Task { await handlePicked(data) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await handlePicked(data)
                    }
                }
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
                // 실패가 막다른 길이 되지 않게 한다. 얼럿 대신 안내 후 직접 입력으로 이어진다.
                Text("사진에서 글자를 찾지 못했습니다. 아래에 직접 입력해 주세요.")
            } else {
                Text("사진은 기기 안에서만 분석됩니다. 외부로 전송되지 않습니다.")
            }
        }
    }

    private var textSection: some View {
        Section {
            TextEditor(text: $userEditedText)
                .frame(minHeight: 120)
                .accessibilityLabel("문제 내용")
        } header: {
            Text("문제 내용")
        } footer: {
            Text("사진에서 읽은 글자입니다. 틀린 부분을 고쳐 주세요.")
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
    }

    private func save() {
        let note = editing ?? WrongAnswerNote()

        note.ocrRawText = ocrRawText          // 원본은 보존한다
        note.userEditedText = userEditedText.trimmed
        note.causeTag = causeTag
        note.englishSubcategory = englishSubcategory
        note.imageData = imageData

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
