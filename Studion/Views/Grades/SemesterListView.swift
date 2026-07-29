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
            SemesterFormView(
                defaultSystem: profile?.gradingSystemType ?? .fiveTier,
                admissionYear: profile?.admissionYear ?? Calendar.current.component(.year, from: Date())
            )
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
    let admissionYear: Int

    @State private var year: Int
    @State private var term = 1
    @State private var system: GradingSystemType
    @State private var includeCommonSubjects = true

    init(defaultSystem: GradingSystemType, admissionYear: Int) {
        self.defaultSystem = defaultSystem
        self.admissionYear = admissionYear
        _system = State(initialValue: defaultSystem)
        // 첫 학기는 보통 입학연도다. 현재 연도를 기본값으로 두면 이미 지난 학년으로 잡혀
        // 고1 공통과목 제안이 나오지 않는다.
        let currentYear = Calendar.current.component(.year, from: Date())
        _year = State(initialValue: max(admissionYear, min(currentYear, admissionYear + 2)))
    }

    private var revision: CurriculumRevision {
        CurriculumRevision.forAdmissionYear(admissionYear)
    }

    /// 이 학기가 몇 학년인지. 입학연도로 계산한다.
    private var gradeLevel: Int { year - admissionYear + 1 }

    /// 공통과목은 고1에만 있다.
    private var isFirstYear: Bool { gradeLevel == 1 }

    private var commonSubjects: [SubjectPreset] {
        CurriculumPreset.commonSubjects(for: revision, term: term)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("학년도", selection: $year) {
                    // 입학연도부터 3년(고1~고3)을 기본 범위로 두고, 재수·검정고시 등을 위해
                    // 앞뒤로 한 해씩 여유를 준다.
                    ForEach((admissionYear - 1)...(admissionYear + 3), id: \.self) { value in
                        Text(verbatim: "\(value)").tag(value)
                    }
                }
                Picker("학기", selection: $term) {
                    Text("1학기").tag(1)
                    Text("2학기").tag(2)
                }

                if (1...3).contains(gradeLevel) {
                    LabeledContent("학년") {
                        Text("고\(gradeLevel)")
                            .foregroundStyle(.secondary)
                    }
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

                if isFirstYear {
                    commonSubjectsSection
                }
            }
            .navigationTitle("학기 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                }
            }
        }
    }

    /// 고1 공통과목은 국가 교육과정이 정해 전국이 같다. 매번 타이핑하지 않도록 미리 넣어준다.
    /// 넣은 뒤에도 이름·단위·평가 방식을 자유롭게 고칠 수 있다.
    private var commonSubjectsSection: some View {
        Section {
            Toggle("공통과목 함께 추가", isOn: $includeCommonSubjects)

            if includeCommonSubjects {
                ForEach(commonSubjects) { preset in
                    HStack {
                        Text(verbatim: preset.name)
                        Spacer()
                        Text("\(preset.creditUnits, format: .number.precision(.fractionLength(0)))단위")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        } header: {
            Text("고1 공통과목")
        } footer: {
            if includeCommonSubjects {
                if CurriculumPreset.creditUnitsAreAnnual(for: revision) {
                    Text("\(revision.displayName) 기준입니다. 이수단위는 **연간 기준**이라 학기별로 나눠 들으면 값을 고쳐 주세요. 과목은 나중에 언제든 수정·삭제할 수 있습니다.")
                } else {
                    Text("\(revision.displayName) 기준입니다. 학교 편성에 따라 다를 수 있으니 확인 후 고쳐 주세요.")
                }
            }
        }
    }

    private func save() {
        let semester = Semester(year: year, term: term, gradingSystemType: system)
        context.insert(semester)

        if isFirstYear, includeCommonSubjects {
            for preset in commonSubjects {
                let record = SchoolSubjectRecord(
                    subjectName: preset.name,
                    creditUnits: preset.creditUnits,
                    evaluationType: preset.evaluationType,
                    semester: semester
                )
                context.insert(record)
            }
        }

        dismiss()
    }
}
