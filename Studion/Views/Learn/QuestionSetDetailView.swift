import SwiftUI
import SwiftData

/// 문제집 상세. 문제 카드 목록과 풀기 진입점.
struct QuestionSetDetailView: View {
    @Environment(\.modelContext) private var context

    let questionSet: QuestionSet

    @State private var isAddingQuestion = false
    @State private var questionToEdit: Question?

    private var questions: [Question] { questionSet.sortedQuestions }

    /// 풀 수 있는 문제가 하나라도 있어야 세션을 시작한다.
    private var answerableCount: Int {
        questions.filter(\.isAnswerable).count
    }

    var body: some View {
        Group {
            if questions.isEmpty {
                EmptyStateView(
                    systemImage: "square.and.pencil",
                    title: "문제가 없어요",
                    message: "첫 문제를 출제해 보세요.",
                    actionTitle: "문제 출제",
                    action: { isAddingQuestion = true }
                )
            } else {
                List {
                    if answerableCount > 0 {
                        Section {
                            NavigationLink {
                                QuizSessionView(questionSet: questionSet)
                            } label: {
                                Label("문제 풀기", systemImage: "play.circle")
                            }
                        } footer: {
                            if answerableCount < questions.count {
                                Text("작성이 끝나지 않은 문제 \(questions.count - answerableCount)개는 세션에서 제외됩니다.")
                            }
                        }
                    }

                    Section("문제 \(questions.count)개") {
                        ForEach(questions) { question in
                            Button {
                                questionToEdit = question
                            } label: {
                                QuestionRow(question: question)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteQuestions)
                    }
                }
            }
        }
        .navigationTitle(questionSet.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingQuestion = true
                } label: {
                    Label("문제 출제", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingQuestion) {
            QuestionFormView(questionSet: questionSet)
        }
        .sheet(item: $questionToEdit) { question in
            QuestionFormView(questionSet: questionSet, editing: question)
        }
    }

    private func deleteQuestions(at offsets: IndexSet) {
        for index in offsets {
            context.delete(questions[index])
        }
        questionSet.touch()
    }
}

private struct QuestionRow: View {
    @ScaledMetric(relativeTo: .subheadline) private var thumbnailSize: CGFloat = 44

    let question: Question

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let data = question.questionImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: question.prompt)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Label(question.type.displayName, systemImage: question.type.systemImage)
                    if !question.isAnswerable {
                        Text("작성 중")
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
