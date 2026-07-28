import SwiftUI
import SwiftData
import Charts

/// 내신 과목 상세. ① 성적 추이 ② 목표 진척 게이지 ③ 오답노트 리스트.
struct SubjectDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar

    let record: SchoolSubjectRecord

    @Query(sort: [SortDescriptor(\Semester.year), SortDescriptor(\Semester.term)])
    private var semesters: [Semester]

    @State private var isAddingNote = false
    @State private var noteToEdit: WrongAnswerNote?
    @State private var subcategoryFilter: EnglishSubcategory?

    private var notes: [WrongAnswerNote] {
        (record.wrongAnswerNotes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    /// 영어 하위 카테고리 필터는 **과목명 문자열로 판단하지 않는다.**
    /// 오답노트에 실제로 영역이 지정된 적이 있을 때만 노출한다.
    private var hasEnglishSubcategories: Bool {
        notes.contains { $0.englishSubcategory != nil }
    }

    private var filteredNotes: [WrongAnswerNote] {
        guard let subcategoryFilter else { return notes }
        return notes.filter { $0.englishSubcategory == subcategoryFilter }
    }

    private var system: GradingSystemType {
        record.semester?.gradingSystemType ?? .fiveTier
    }

    /// 같은 과목명을 가진 다른 학기의 기록. 과목 동일성은 trim 후 완전 일치로 판정한다.
    private var history: [(semester: Semester, grade: Int)] {
        let name = record.subjectName.trimmed
        return semesters.compactMap { semester in
            guard let match = (semester.subjectRecords ?? []).first(where: {
                $0.subjectName.trimmed == name
            }), let grade = match.rankGrade else { return nil }
            return (semester, grade)
        }
    }

    private var progress: ProgressCalculator.GradeProgress? {
        guard let current = record.rankGrade, let target = record.targetGrade else { return nil }
        return ProgressCalculator.progress(current: current, target: target, system: system)
    }

    var body: some View {
        List {
            Section("성적 추이") {
                if history.count >= 2 {
                    trendChart
                } else if let grade = record.rankGrade {
                    LabeledContent("현재 등급") {
                        Text("\(grade)등급").monospacedDigit()
                    }
                } else {
                    Text("아직 등급 기록이 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("목표 대비") {
                if let progress, let current = record.rankGrade, let target = record.targetGrade {
                    ProgressGauge(progress: progress, currentGrade: current, targetGrade: target)
                        .padding(.vertical, 4)
                } else if record.evaluationType == .achievementOnly {
                    Text("성취도만 기재하는 과목은 목표 등급을 설정하지 않습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("석차등급과 목표 등급을 입력하면 진척이 표시됩니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            wrongAnswerSection
        }
        .navigationTitle(record.subjectName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingNote = true
                } label: {
                    Label("오답노트 추가", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingNote) {
            WrongAnswerFormView(schoolSubject: record)
        }
        .sheet(item: $noteToEdit) { note in
            WrongAnswerFormView(schoolSubject: record, editing: note)
        }
    }

    @ViewBuilder
    private var wrongAnswerSection: some View {
        Section {
            if notes.isEmpty {
                ContentUnavailableView {
                    Label("오답노트가 없어요", systemImage: "doc.text.image")
                } description: {
                    Text("틀린 문제를 찍어 오답노트를 만들어 보세요.")
                } actions: {
                    Button("사진으로 추가") { isAddingNote = true }
                }
            } else {
                if hasEnglishSubcategories {
                    Picker("영역", selection: $subcategoryFilter) {
                        Text("전체").tag(EnglishSubcategory?.none)
                        ForEach(EnglishSubcategory.allCases) { item in
                            Text(item.displayName).tag(EnglishSubcategory?.some(item))
                        }
                    }
                    .pickerStyle(.segmented)
                }

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
                            imageData: note.imageData
                        )
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteNotes)
            }
        } header: {
            Text("오답노트")
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredNotes[index])
        }
    }

    private var trendChart: some View {
        Chart(history, id: \.semester.persistentModelID) { item in
            LineMark(
                x: .value("학기", item.semester.displayName),
                y: .value("등급", item.grade)
            )
            PointMark(
                x: .value("학기", item.semester.displayName),
                y: .value("등급", item.grade)
            )
        }
        // 등급은 작을수록 좋으므로 1등급이 위로 오게 축을 뒤집는다.
        .chartYScale(domain: [Double(system.tierCount), 1])
        .frame(minHeight: 200)
        .accessibilityLabel("\(record.subjectName) 등급 추이")
        .accessibilityValue("학기 \(history.count)개")
    }
}
