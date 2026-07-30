import SwiftUI
import SwiftData

/// 학습 탭. 문제 모음집 목록.
///
/// 명세: `docs/08-question-bank.md`
struct LearnView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \QuestionSet.updatedAt, order: .reverse)
    private var sets: [QuestionSet]

    @State private var isAddingSet = false
    @State private var setToEdit: QuestionSet?
    /// 원래 오늘 할 일 탭에 있던 진입로 — 시간표도 학습 계획의 일부라 이쪽으로 옮겼다.
    @State private var isShowingTimetable = false

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
                    Button {
                        isShowingTimetable = true
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .accessibilityLabel("시간표 관리")
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
            .sheet(isPresented: $isShowingTimetable) {
                NavigationStack {
                    TimetableListView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("닫기") { isShowingTimetable = false }
                            }
                        }
                }
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
