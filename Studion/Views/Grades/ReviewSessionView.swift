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
                        Text(note.userEditedText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
    }
}
