import SwiftUI
import SwiftData

/// 오답노트 모아 보기. 학습 탭의 진입로다.
///
/// 오답노트는 과목에 딸려 있지만 **공부할 때는 과목을 넘나들며 본다** — 그래서 기록(과목별)과
/// 별개로, 전부 모아 놓고 복습으로 바로 들어가는 화면을 학습 쪽에 둔다.
/// 과목 상세의 오답노트 목록은 그 과목의 기록으로 그대로 남는다.
struct WrongAnswerHubView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar

    @Query(sort: \WrongAnswerNote.createdAt, order: .reverse)
    private var allNotes: [WrongAnswerNote]

    @State private var subjectFilter: String?
    @State private var noteToEdit: WrongAnswerNote?

    private var dueCount: Int {
        allNotes.filter {
            ReviewScheduler.isDue(nextReviewDate: $0.nextReviewDate, on: Date(), calendar: calendar)
        }.count
    }

    /// 필터에 쓸 과목명. 내신·모의고사를 굳이 나누지 않는다 — 학생에게는 "수학"이 하나다.
    private var subjectNames: [String] {
        let names = allNotes.compactMap(subjectName)
        return Array(Set(names)).sorted()
    }

    private var filteredNotes: [WrongAnswerNote] {
        guard let subjectFilter else { return allNotes }
        return allNotes.filter { subjectName($0) == subjectFilter }
    }

    var body: some View {
        Group {
            if allNotes.isEmpty {
                EmptyStateView(
                    systemImage: "doc.text.image",
                    title: "오답노트가 없어요",
                    message: "기록 탭에서 과목을 열고 틀린 문제를 찍어 만들어 보세요."
                )
            } else {
                List {
                    reviewSection
                    notesSection
                }
            }
        }
        .navigationTitle("오답노트")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if subjectNames.count > 1 {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("과목", selection: $subjectFilter) {
                            Text("전체").tag(String?.none)
                            ForEach(subjectNames, id: \.self) { name in
                                Text(verbatim: name).tag(String?.some(name))
                            }
                        }
                    } label: {
                        Label(subjectFilter ?? String(localized: "과목"), systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(item: $noteToEdit) { note in
            editForm(for: note)
        }
        // 필터로 걸어둔 과목의 노트를 모두 지우면 빈 목록만 남는다. 전체로 되돌린다.
        .onChange(of: subjectNames) { _, names in
            if let subjectFilter, !names.contains(subjectFilter) {
                self.subjectFilter = nil
            }
        }
    }

    private var reviewSection: some View {
        Section {
            NavigationLink {
                ReviewSessionView()
            } label: {
                HStack {
                    Label("복습 시작", systemImage: "rectangle.on.rectangle.angled")
                    Spacer()
                    // 밀린 카드 수를 재촉하듯 강조하지 않는다 — 숫자만 담담히 둔다.
                    Text(dueCount > 0 ? "\(dueCount)장" : "오늘은 없음")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("복습할 때가 된 카드부터 보여줍니다.")
        }
    }

    private var notesSection: some View {
        Section {
            ForEach(filteredNotes) { note in
                Button {
                    noteToEdit = note
                } label: {
                    WrongAnswerCard(
                        text: note.userEditedText,
                        causeTag: note.causeTag,
                        englishSubcategory: note.englishSubcategory,
                        isDue: ReviewScheduler.isDue(
                            nextReviewDate: note.nextReviewDate, on: Date(), calendar: calendar
                        ),
                        imageData: note.imageData,
                        isMultipleChoice: note.isMultipleChoice
                    )
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteNotes)
        } header: {
            Text("모든 오답노트")
        }
    }

    /// 편집 화면은 노트가 어느 쪽 과목에 달려 있는지에 따라 받는 인자가 다르다.
    @ViewBuilder
    private func editForm(for note: WrongAnswerNote) -> some View {
        if let subject = note.schoolSubject {
            WrongAnswerFormView(schoolSubject: subject, editing: note)
        } else if let subject = note.mockExamSubject {
            WrongAnswerFormView(mockExamSubject: subject, editing: note)
        } else {
            // 과목이 지워져 홀로 남은 노트도 고칠 수는 있어야 한다.
            WrongAnswerFormView(editing: note)
        }
    }

    private func subjectName(_ note: WrongAnswerNote) -> String? {
        note.schoolSubject?.subjectName ?? note.mockExamSubject?.subjectName
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredNotes[index])
        }
    }
}
