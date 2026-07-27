import SwiftUI
import SwiftData

/// 내신 서브탭. 학기를 고르고 그 학기의 이수 과목을 관리한다.
struct SemesterListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Semester.year, order: .reverse),
                  SortDescriptor(\Semester.term, order: .reverse)])
    private var semesters: [Semester]

    @Query private var profiles: [AcademicProfile]

    @State private var selectedSemesterID: PersistentIdentifier?
    @State private var showingSemesterForm = false
    @State private var subjectToEdit: SchoolSubjectRecord?
    @State private var isAddingSubject = false

    private var profile: AcademicProfile? { profiles.first }

    private var selectedSemester: Semester? {
        semesters.first { $0.persistentModelID == selectedSemesterID } ?? semesters.first
    }

    private var subjects: [SchoolSubjectRecord] {
        (selectedSemester?.subjectRecords ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// 등급이 산출되는 과목만으로 계산한다. 성취도만 기재하는 과목은 분모에서도 제외된다.
    private var weightedAverage: Double? {
        let inputs = subjects.compactMap { record -> GradeCalculator.WeightedGradeInput? in
            guard record.evaluationType == .achievementAndRank,
                  let grade = record.rankGrade
            else { return nil }
            return .init(grade: grade, creditUnits: record.creditUnits)
        }
        return GradeCalculator.weightedAverageGrade(inputs)
    }

    private var excludedSubjectCount: Int {
        subjects.filter { $0.evaluationType == .achievementOnly }.count
    }

    var body: some View {
        Group {
            if semesters.isEmpty {
                EmptyStateView(
                    systemImage: "calendar.badge.plus",
                    title: "학기가 없어요",
                    message: "학기를 추가하면 이수 과목과 성적을 기록할 수 있습니다.",
                    actionTitle: "학기 추가",
                    action: { showingSemesterForm = true }
                )
            } else {
                semesterContent
            }
        }
        .toolbar {
            if !semesters.isEmpty, selectedSemester != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingSubject = true
                    } label: {
                        Label("과목 추가", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSemesterForm) {
            SemesterFormView(defaultSystem: profile?.gradingSystemType ?? .fiveTier)
        }
        .sheet(isPresented: $isAddingSubject) {
            if let selectedSemester {
                SubjectFormView(semester: selectedSemester)
            }
        }
        .sheet(item: $subjectToEdit) { record in
            if let semester = record.semester {
                SubjectFormView(semester: semester, editing: record)
            }
        }
        .onAppear(perform: ensureProfileExists)
    }

    // MARK: - 학기 선택 + 과목 리스트

    private var semesterContent: some View {
        List {
            Section {
                Picker("학기", selection: Binding(
                    get: { selectedSemester?.persistentModelID },
                    set: { selectedSemesterID = $0 }
                )) {
                    ForEach(semesters) { semester in
                        Text(semester.displayName).tag(Optional(semester.persistentModelID))
                    }
                }
                Button("학기 추가") { showingSemesterForm = true }
            }

            if let selectedSemester {
                Section {
                    if subjects.isEmpty {
                        ContentUnavailableView {
                            Label("이수 과목이 없어요", systemImage: "book.closed")
                        } description: {
                            Text("이 학기에 듣는 과목을 추가해 보세요.")
                        } actions: {
                            Button("과목 추가") { isAddingSubject = true }
                        }
                    } else {
                        ForEach(subjects) { record in
                            NavigationLink {
                                SubjectDetailView(record: record)
                            } label: {
                                SubjectRow(record: record)
                            }
                            .swipeActions(edge: .leading) {
                                Button("편집") { subjectToEdit = record }
                                    .tint(.accentColor)
                            }
                        }
                        .onDelete(perform: deleteSubjects)

                        NavigationLink {
                            GoalProgressView(semester: selectedSemester)
                        } label: {
                            Label("목표 대비 진척 보기", systemImage: "target")
                        }
                    }
                } header: {
                    semesterHeader(selectedSemester)
                } footer: {
                    if excludedSubjectCount > 0 {
                        Text("성취도만 기재하는 \(excludedSubjectCount)개 과목은 평균 등급 계산에서 제외됩니다.")
                    }
                }
            }
        }
    }

    private func semesterHeader(_ semester: Semester) -> some View {
        HStack {
            Text(semester.gradingSystemType.displayName)
            Spacer()
            if let weightedAverage {
                Text("평균 \(weightedAverage, format: .number.precision(.fractionLength(2)))등급")
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 동작

    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        context.insert(AcademicProfile())
    }

    private func deleteSubjects(at offsets: IndexSet) {
        for index in offsets {
            context.delete(subjects[index])
        }
    }
}

// MARK: - 과목 행

private struct SubjectRow: View {
    let record: SchoolSubjectRecord

    private var isGoalAchieved: Bool? {
        guard let grade = record.rankGrade, let target = record.targetGrade else { return nil }
        return grade <= target
    }

    private var badgeContent: GradeBadge.Content {
        if record.evaluationType == .achievementOnly {
            return record.achievementLevel.map { .achievement($0) } ?? .none
        }
        if let grade = record.rankGrade { return .grade(grade) }
        if let level = record.achievementLevel { return .achievement(level) }
        return .none
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.subjectName)
                    .font(.body)
                Text("\(record.creditUnits, format: .number.precision(.fractionLength(0)))단위")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GradeBadge(content: badgeContent, isGoalAchieved: isGoalAchieved)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - 학기 추가

private struct SemesterFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let defaultSystem: GradingSystemType

    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var term = 1
    @State private var system: GradingSystemType

    init(defaultSystem: GradingSystemType) {
        self.defaultSystem = defaultSystem
        _system = State(initialValue: defaultSystem)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("학년도", selection: $year) {
                    ForEach((year - 5)...(year + 1), id: \.self) { value in
                        Text(verbatim: "\(value)").tag(value)
                    }
                }
                Picker("학기", selection: $term) {
                    Text("1학기").tag(1)
                    Text("2학기").tag(2)
                }
                Section {
                    Picker("등급제", selection: $system) {
                        ForEach(GradingSystemType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                } footer: {
                    Text("학기를 만들 때 등급제가 고정됩니다. 나중에 설정을 바꿔도 이 학기의 기록은 그대로 유지됩니다.")
                }
            }
            .navigationTitle("학기 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        context.insert(Semester(year: year, term: term, gradingSystemType: system))
                        dismiss()
                    }
                }
            }
        }
    }
}
