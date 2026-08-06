import SwiftUI
import SwiftData

/// 플래시카드 복습.
///
/// 카드마다 **"맞음 / 틀림" 두 개 동작만** 둔다. 난이도 5단계 같은 걸 만들지 않는다.
/// 밀린 카드를 압박하는 문구도 쓰지 않는다.
struct ReviewSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar

    @Query private var allNotes: [WrongAnswerNote]

    @State private var currentIndex = 0
    @State private var isTextRevealed = false
    /// 객관식 카드에서 학생이 방금 골라본 보기. 채점 여부와 무관하게 이번 카드에서만 유지된다.
    @State private var selectedChoiceIndex: Int?
    /// 이번 세션에서 이미 처리한 카드. 다시 due가 되어도 세션 안에서는 돌아오지 않게 한다.
    @State private var reviewedIDs: Set<PersistentIdentifier> = []

    private var dueNotes: [WrongAnswerNote] {
        allNotes
            .filter {
                !reviewedIDs.contains($0.persistentModelID)
                    && ReviewScheduler.isDue(nextReviewDate: $0.nextReviewDate, on: Date(), calendar: calendar)
            }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    private var currentNote: WrongAnswerNote? {
        dueNotes.indices.contains(currentIndex) ? dueNotes[currentIndex] : dueNotes.first
    }

    var body: some View {
        Group {
            if let currentNote {
                card(for: currentNote)
            } else {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "오늘 복습할 카드가 없어요",
                    message: "새 오답노트를 만들면 복습 일정이 잡힙니다."
                )
            }
        }
        .navigationTitle("복습")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(for note: WrongAnswerNote) -> some View {
        VStack(spacing: 16) {
            Text("남은 카드 \(dueNotes.count)장")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 12) {
                    if let imageData = note.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("오답 문제 사진")
                    }

                    if isTextRevealed {
                        content(for: note)
                            .transition(.opacity)
                    } else {
                        Button("내용 보기") {
                            withAnimation { isTextRevealed = true }
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 6) {
                        Text(note.causeTag.displayName)
                        if let sub = note.englishSubcategory {
                            Text("· \(sub.displayName)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }

            HStack(spacing: 12) {
                Button {
                    record(note, outcome: .incorrect)
                } label: {
                    Label("틀림", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    record(note, outcome: .correct)
                } label: {
                    Label("맞음", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - 카드 내용

    /// 지문 · 문제 · 선택지 · 해설 순으로 보여준다 — 오답노트를 만들 때 넣은 칸 그대로다.
    ///
    /// 정답을 지정해 뒀으면 고르는 즉시 채점하고, 모르면(비워뒀으면) 채점 없이 골라보기만
    /// 한다 — 앱이 정답을 추정하지 않는다.
    @ViewBuilder
    private func content(for note: WrongAnswerNote) -> some View {
        let content = note.content

        VStack(alignment: .leading, spacing: 12) {
            if !content.passage.isEmpty {
                Text(verbatim: content.passage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !content.prompt.isEmpty {
                Text(verbatim: content.prompt)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if note.isMultipleChoice, content.isMultipleChoice {
                choiceList(content.choices, note: note)
            }

            if !note.explanation.isEmpty {
                Divider()
                Text(verbatim: note.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choiceList(_ choices: [String], note: WrongAnswerNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                Button {
                    selectedChoiceIndex = index
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text(verbatim: String(MultipleChoiceParser.choiceMarkers[index]))
                            .fontWeight(.semibold)
                        Text(verbatim: choice)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        choiceStatusIcon(index: index, note: note)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(choiceBackground(index: index, note: note), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func choiceStatusIcon(index: Int, note: WrongAnswerNote) -> some View {
        if let correct = note.correctChoiceIndex {
            if index == correct {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color("GoalAchieved"))
            } else if selectedChoiceIndex == index {
                // 오답을 빨간색으로 강조하지 않는다 — 뉴트럴 톤의 빈 원으로만 표시.
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        } else if selectedChoiceIndex == index {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func choiceBackground(index: Int, note: WrongAnswerNote) -> Color {
        if let correct = note.correctChoiceIndex {
            if index == correct { return Color("GoalAchieved").opacity(0.15) }
            if selectedChoiceIndex == index { return Color.secondary.opacity(0.12) }
            return .clear
        }
        return selectedChoiceIndex == index ? Color.secondary.opacity(0.12) : .clear
    }

    private func record(_ note: WrongAnswerNote, outcome: ReviewScheduler.ReviewOutcome) {
        let schedule = ReviewScheduler.nextSchedule(
            currentBox: note.leitnerBoxIndex,
            outcome: outcome,
            reviewedAt: Date(),
            calendar: calendar
        )
        note.leitnerBoxIndex = schedule.boxIndex
        note.nextReviewDate = schedule.nextReviewDate
        note.lastReviewedAt = Date()

        reviewedIDs.insert(note.persistentModelID)
        currentIndex = 0
        isTextRevealed = false
        selectedChoiceIndex = nil
    }
}
