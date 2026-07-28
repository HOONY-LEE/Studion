import SwiftUI
import SwiftData

/// 문제 풀이 세션. 한 모음집을 처음부터 끝까지 푼다.
///
/// 명세: `docs/08-question-bank.md` §6
/// 점수·랭킹·스트릭을 만들지 않는다. 오답을 빨간색으로 강조하지 않는다.
struct QuizSessionView: View {
    let questionSet: QuestionSet

    /// 이번 세션에서 풀 문제. 미완성 카드는 제외한다.
    @State private var queue: [Question] = []
    @State private var currentIndex = 0
    @State private var isShuffled = false

    /// 이번 문제의 답변 상태
    @State private var selectedChoiceIndex: Int?
    @State private var typedAnswer = ""
    @State private var isRevealed = false
    @State private var result: QuestionGrader.Result = .notGraded

    /// 세션 집계
    @State private var correctCount = 0
    @State private var gradedCount = 0
    @State private var wrongQuestions: [Question] = []
    @State private var isFinished = false

    private var currentQuestion: Question? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    var body: some View {
        Group {
            if isFinished {
                summary
            } else if let question = currentQuestion {
                questionCard(question)
            } else {
                EmptyStateView(
                    systemImage: "square.and.pencil",
                    title: "풀 수 있는 문제가 없어요",
                    message: "문제를 완성하면 여기서 풀 수 있습니다."
                )
            }
        }
        .navigationTitle(questionSet.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: startSessionIfNeeded)
    }

    // MARK: - 문제 화면

    private func questionCard(_ question: Question) -> some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(currentIndex), total: Double(max(queue.count, 1)))
                .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(currentIndex + 1) / \(queue.count)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)

                    if !question.passageText.isEmpty {
                        Text(verbatim: question.passageText)
                            .font(.callout)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    }

                    if let data = question.questionImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("문제 이미지")
                    }

                    Text(verbatim: question.prompt)
                        .font(.title3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !question.hint.isEmpty, !isRevealed {
                        Label(question.hint, systemImage: "lightbulb")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    answerArea(question)

                    if isRevealed {
                        feedback(question)
                    }
                }
                .padding()
            }

            bottomBar(question)
        }
    }

    @ViewBuilder
    private func answerArea(_ question: Question) -> some View {
        switch question.type {
        case .multipleChoice:
            VStack(spacing: 8) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        guard !isRevealed else { return }
                        selectedChoiceIndex = index
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text(verbatim: "\(index + 1)")
                                .fontWeight(.semibold)
                            Text(verbatim: choice)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            choiceIcon(index: index, question: question)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            choiceBackground(index: index, question: question),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

        case .flashcard:
            if isRevealed {
                Text(verbatim: question.flashcardBack)
                    .font(.title3.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }

        case .fillInBlank, .shortAnswer:
            TextField("답 입력", text: $typedAnswer)
                .textFieldStyle(.roundedBorder)
                .disabled(isRevealed)
                .submitLabel(.done)
                .onSubmit { if !isRevealed { checkAnswer(question) } }
        }
    }

    @ViewBuilder
    private func choiceIcon(index: Int, question: Question) -> some View {
        if isRevealed, let correct = question.correctChoiceIndex {
            if index == correct {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color("GoalAchieved"))
            } else if selectedChoiceIndex == index {
                // 오답을 빨간색으로 강조하지 않는다.
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        } else if selectedChoiceIndex == index {
            Image(systemName: "largecircle.fill.circle")
                .foregroundStyle(.tint)
        }
    }

    private func choiceBackground(index: Int, question: Question) -> Color {
        if isRevealed, let correct = question.correctChoiceIndex, index == correct {
            return Color("GoalAchieved").opacity(0.15)
        }
        return selectedChoiceIndex == index ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.06)
    }

    @ViewBuilder
    private func feedback(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch result {
            case .correct:
                Label("정답", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color("GoalAchieved"))
            case .incorrect:
                // "틀렸습니다" 대신 정답을 알려주는 데 집중한다.
                VStack(alignment: .leading, spacing: 4) {
                    Label("정답은", systemImage: "arrow.turn.down.right")
                        .foregroundStyle(.secondary)
                    Text(verbatim: correctAnswerText(question))
                        .font(.body.weight(.medium))
                }
            case .notGraded:
                EmptyView()
            }

            if !question.explanation.isEmpty {
                Text(verbatim: question.explanation)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let data = question.explanationImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("해설 이미지")
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func correctAnswerText(_ question: Question) -> String {
        if question.type.usesChoices, let index = question.correctChoiceIndex,
           question.choices.indices.contains(index) {
            return "\(index + 1). \(question.choices[index])"
        }
        return question.acceptedAnswers.joined(separator: " / ")
    }

    // MARK: - 하단 버튼

    @ViewBuilder
    private func bottomBar(_ question: Question) -> some View {
        VStack(spacing: 8) {
            if !isRevealed {
                if question.type == .flashcard {
                    Button("답 보기") { reveal(question) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Button("확인") { checkAnswer(question) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(!hasAnswer(question))
                }
            } else if question.type == .flashcard {
                // 플래시카드는 앱이 채점하지 않고 학생이 스스로 판단한다.
                HStack(spacing: 12) {
                    Button {
                        recordSelfGrade(isCorrect: false, question: question)
                    } label: {
                        Label("몰랐음", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        recordSelfGrade(isCorrect: true, question: question)
                    } label: {
                        Label("알았음", systemImage: "checkmark")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button(currentIndex + 1 < queue.count ? "다음 문제" : "결과 보기") {
                    goToNext()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding()
    }

    private func hasAnswer(_ question: Question) -> Bool {
        question.type.usesChoices ? selectedChoiceIndex != nil : !typedAnswer.trimmed.isEmpty
    }

    // MARK: - 세션 결과

    private var summary: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "flag.checkered")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("다 풀었어요")
                .font(.title2.weight(.semibold))

            if gradedCount > 0 {
                Text("\(gradedCount)문제 중 \(correctCount)개 맞았습니다.")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 8) {
                if !wrongQuestions.isEmpty {
                    Button("틀린 문제만 다시 풀기") { restartWithWrongOnly() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                Button("처음부터 다시 풀기") { startSession(shuffled: isShuffled) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding()
        }
    }

    // MARK: - 동작

    private func startSessionIfNeeded() {
        guard queue.isEmpty else { return }
        startSession(shuffled: false)
    }

    private func startSession(shuffled: Bool) {
        let answerable = questionSet.sortedQuestions.filter(\.isAnswerable)
        queue = shuffled ? answerable.shuffled() : answerable
        isShuffled = shuffled
        resetSessionCounters()
    }

    private func restartWithWrongOnly() {
        queue = wrongQuestions
        resetSessionCounters()
    }

    private func resetSessionCounters() {
        currentIndex = 0
        correctCount = 0
        gradedCount = 0
        wrongQuestions = []
        isFinished = false
        resetAnswerState()
    }

    private func resetAnswerState() {
        selectedChoiceIndex = nil
        typedAnswer = ""
        isRevealed = false
        result = .notGraded
    }

    private func checkAnswer(_ question: Question) {
        switch question.type {
        case .multipleChoice:
            result = QuestionGrader.gradeMultipleChoice(
                selected: selectedChoiceIndex,
                correctIndex: question.correctChoiceIndex
            )
        case .fillInBlank, .shortAnswer:
            result = QuestionGrader.gradeTextAnswer(
                typedAnswer,
                acceptedAnswers: question.acceptedAnswers
            )
        case .flashcard:
            result = .notGraded
        }

        if result != .notGraded {
            gradedCount += 1
            if result == .correct {
                correctCount += 1
            } else {
                wrongQuestions.append(question)
            }
        }

        isRevealed = true
    }

    private func reveal(_ question: Question) {
        result = .notGraded
        isRevealed = true
    }

    private func recordSelfGrade(isCorrect: Bool, question: Question) {
        gradedCount += 1
        if isCorrect {
            correctCount += 1
        } else {
            wrongQuestions.append(question)
        }
        goToNext()
    }

    private func goToNext() {
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            resetAnswerState()
        } else {
            isFinished = true
        }
    }
}
