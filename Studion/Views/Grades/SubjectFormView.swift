import SwiftUI
import SwiftData

/// 내신 과목 추가/편집 화면.
///
/// "이 과목은 석차등급이 산출되나요?"의 답에 따라 입력 필드 구성이 갈린다.
/// 교육과정 프리셋이 이 값을 **제안**하지만, 최종 결정은 항상 사용자가 한다 —
/// 학교 편성과 교육과정 개정에 따라 달라질 수 있기 때문이다.
struct SubjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let semester: Semester
    /// 편집 대상. `nil`이면 새로 추가하는 것이다.
    var editing: SchoolSubjectRecord?
    /// 과목 이름 추천에 쓸 교육과정. 학기의 등급제로 역산한다.
    private var revision: CurriculumRevision {
        semester.gradingSystemType == .fiveTier ? .revision2022 : .revision2015
    }

    /// 입력 중인 이름과 겹치는 추천 과목. 이미 정확히 일치하면 보여주지 않는다.
    private var matchingSuggestions: [String] {
        let query = subjectName.trimmed
        guard !query.isEmpty else { return [] }

        let candidates = CurriculumPreset.suggestedElectiveNames(for: revision)
        let matches = candidates.filter { $0.localizedStandardContains(query) }
        // 이미 정확히 고른 상태면 목록을 접는다.
        guard !(matches.count == 1 && matches[0] == query) else { return [] }
        return Array(matches.prefix(6))
    }

    @State private var subjectName = ""
    @State private var isPickingFromCatalog = false
    @State private var evaluationType: SchoolSubjectEvaluationType = .achievementAndRank
    @State private var creditUnitsText = ""
    @State private var rawScoreText = ""
    @State private var subjectAverageText = ""
    @State private var stdDeviationText = ""
    @State private var studentCountText = ""
    @State private var achievementLevel: AchievementLevel?
    @State private var rankGrade: Int?
    @State private var targetGrade: Int?

    private var system: GradingSystemType { semester.gradingSystemType }

    private var creditUnits: Double? { Double(creditUnitsText.trimmed) }
    private var rawScore: Double? { Double(rawScoreText.trimmed) }
    private var subjectAverage: Double? { Double(subjectAverageText.trimmed) }
    private var stdDeviation: Double? { Double(stdDeviationText.trimmed) }
    private var studentCount: Int? { Int(studentCountText.trimmed) }

    private var canSave: Bool {
        !subjectName.trimmed.isEmpty && (creditUnits ?? 0) > 0
    }

    private var estimate: GradeCalculator.GradeEstimate? {
        guard evaluationType == .achievementAndRank,
              let rawScore, let subjectAverage, let stdDeviation
        else { return nil }
        return GradeCalculator.estimateGrade(
            rawScore: rawScore,
            subjectAverage: subjectAverage,
            stdDeviation: stdDeviation,
            system: system
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("과목명", text: $subjectName)

                    ForEach(matchingSuggestions, id: \.self) { name in
                        Button {
                            applySuggestion(name)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "text.badge.plus")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(verbatim: name)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isPickingFromCatalog = true
                    } label: {
                        Label("교과별 목록에서 고르기", systemImage: "list.bullet.indent")
                    }

                    numberField("이수단위", text: $creditUnitsText, prompt: "예: 4")
                } footer: {
                    if !matchingSuggestions.isEmpty {
                        Text("자주 쓰이는 과목 이름입니다. 목록에 없으면 그대로 입력하세요.")
                    }
                }

                Section {
                    Picker("석차등급이 산출되나요?", selection: $evaluationType) {
                        Text("예 (일반 과목)").tag(SchoolSubjectEvaluationType.achievementAndRank)
                        Text("아니오 (성취도만)").tag(SchoolSubjectEvaluationType.achievementOnly)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("평가 방식")
                } footer: {
                    Text("사회·과학 융합선택, 체육·예술·교양, 과학탐구실험은 성취도만 기재합니다.")
                }

                Section("성적") {
                    numberField("원점수", text: $rawScoreText)
                    numberField("과목평균", text: $subjectAverageText)

                    // 석차등급이 산출되지 않는 과목은 등급 관련 필드를 화면에서 제거한다.
                    if evaluationType == .achievementAndRank {
                        numberField("표준편차", text: $stdDeviationText)
                        numberField("수강인원", text: $studentCountText,
                                    prompt: "예: 300", keyboard: .numberPad)
                    }

                    Picker("성취도", selection: $achievementLevel) {
                        Text("선택 안 함").tag(AchievementLevel?.none)
                        ForEach(AchievementLevel.allCases) { level in
                            Text(level.rawValue).tag(AchievementLevel?.some(level))
                        }
                    }
                }

                if evaluationType == .achievementAndRank {
                    Section {
                        gradePicker("석차등급", selection: $rankGrade)
                        gradePicker("목표 등급", selection: $targetGrade)
                    } header: {
                        Text("등급")
                    } footer: {
                        if let estimate {
                            estimateFooter(estimate)
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "과목 추가" : "과목 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isPickingFromCatalog) {
                ElectivePickerView(revision: revision) { name in
                    applySuggestion(name)
                }
            }
            .onAppear(perform: loadExistingValues)
        }
    }

    // MARK: - 하위 뷰

    /// 숫자 입력 행.
    ///
    /// `LabeledContent`로 감싸면 빈 상태의 `TextField` 탭 영역이 플레이스홀더 폭까지 좁아져
    /// 최소 터치 타깃(44×44pt)을 만족하지 못한다. `HStack`에서 `TextField`가 남는 폭을
    /// 모두 차지하게 두어 행 오른쪽 전체를 탭할 수 있게 한다.
    private func numberField(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        prompt: LocalizedStringKey = "선택",
        keyboard: UIKeyboardType = .decimalPad
    ) -> some View {
        HStack {
            Text(title)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
        }
    }

    private func gradePicker(_ title: LocalizedStringKey, selection: Binding<Int?>) -> some View {
        Picker(title, selection: selection) {
            Text("선택 안 함").tag(Int?.none)
            ForEach(1...system.tierCount, id: \.self) { grade in
                Text("\(grade)등급").tag(Int?.some(grade))
            }
        }
    }

    private func estimateFooter(_ estimate: GradeCalculator.GradeEstimate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("예상 \(estimate.estimatedGrade)등급")
                    .monospacedDigit()
                EstimateLabel()
            }
            Text("원점수·과목평균·표준편차로 정규분포를 가정해 계산한 값입니다. 실제 등급과 다를 수 있습니다.")
        }
    }

    /// 추천 과목을 고른다. 교육과정이 정한 평가 방식이 있으면 함께 맞춰준다.
    ///
    /// 맞춰준 값도 사용자가 다시 바꿀 수 있다 — 앱이 단정하지 않는다.
    private func applySuggestion(_ name: String) {
        subjectName = name
        if let suggested = CurriculumPreset.suggestedEvaluationType(
            forSubjectNamed: name, revision: revision
        ) {
            evaluationType = suggested
        }
    }

    // MARK: - 저장 / 로드

    private func loadExistingValues() {
        guard let editing else { return }
        subjectName = editing.subjectName
        evaluationType = editing.evaluationType
        creditUnitsText = editing.creditUnits == 0 ? "" : formatted(editing.creditUnits)
        rawScoreText = editing.rawScore.map(formatted) ?? ""
        subjectAverageText = editing.subjectAverage.map(formatted) ?? ""
        stdDeviationText = editing.stdDeviation.map(formatted) ?? ""
        studentCountText = editing.studentCount.map(String.init) ?? ""
        achievementLevel = editing.achievementLevel
        rankGrade = editing.rankGrade
        targetGrade = editing.targetGrade
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private func save() {
        let record = editing ?? SchoolSubjectRecord(semester: semester)

        record.subjectName = subjectName.trimmed
        record.creditUnits = creditUnits ?? 0
        record.evaluationType = evaluationType
        record.rawScore = rawScore
        record.subjectAverage = subjectAverage
        record.achievementLevel = achievementLevel

        if evaluationType == .achievementOnly {
            // 성취도만 기재하는 과목은 등급 관련 값을 갖지 않는다.
            record.stdDeviation = nil
            record.studentCount = nil
            record.rankGrade = nil
            record.targetGrade = nil
        } else {
            record.stdDeviation = stdDeviation
            record.studentCount = studentCount
            record.rankGrade = rankGrade
            record.targetGrade = targetGrade
        }

        if editing == nil {
            record.semester = semester
            context.insert(record)
        }

        dismiss()
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
