import SwiftUI
import SwiftData

/// 학습 탭. 문제 모음집 목록 + 오답노트 진입로.
///
/// 오답노트는 과목별 기록이기도 하지만 **공부하는 곳은 여기**라 진입로를 이 탭에 둔다.
/// 시간표는 반대로 기록 탭에 있다 (→ `GradesView`).
///
/// 명세: `docs/08-question-bank.md`
struct LearnView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \QuestionSet.updatedAt, order: .reverse)
    private var sets: [QuestionSet]

    @State private var isAddingSet = false
    @State private var setToEdit: QuestionSet?

    var body: some View {
        NavigationStack {
            Group {
                if sets.isEmpty {
                    EmptyStateView(
                        systemImage: "rectangle.stack",
                        title: "문제집이 없어요",
                        message: "문제집을 만들고 직접 문제를 출제해 보세요.",
                        actionTitle: "문제집 만들기",
                        action: { isAddingSet = true }
                    )
                } else {
                    List {
                        ForEach(sets) { set in
                            NavigationLink {
                                QuestionSetDetailView(questionSet: set)
                            } label: {
                                QuestionSetRow(questionSet: set)
                            }
                            .swipeActions(edge: .leading) {
                                Button("편집") { setToEdit = set }
                                    .tint(.accentColor)
                            }
                        }
                        .onDelete(perform: deleteSets)
                    }
                }
            }
            .navigationTitle("학습")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        WrongAnswerHubView()
                    } label: {
                        Image(systemName: "doc.text.image")
                    }
                    .accessibilityLabel("오답노트")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingSet = true
                    } label: {
                        Label("문제집 만들기", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingSet) {
                QuestionSetFormView()
            }
            .sheet(item: $setToEdit) { set in
                QuestionSetFormView(editing: set)
            }
        }
    }

    private func deleteSets(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sets[index])
        }
    }
}

private struct QuestionSetRow: View {
    let questionSet: QuestionSet

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(questionSet.title)
                .font(.body)

            HStack(spacing: 6) {
                Text("문제 \(questionSet.questionCount)개")
                    .monospacedDigit()
                if !questionSet.subjectName.trimmed.isEmpty {
                    Text(verbatim: "·")
                    Text(verbatim: questionSet.subjectName)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
    }
}
