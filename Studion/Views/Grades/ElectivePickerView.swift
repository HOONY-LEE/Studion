import SwiftUI

/// 교과(군)별로 선택과목을 훑어보며 고르는 화면.
///
/// 이름을 아는 과목은 폼에서 바로 타이핑하면 되고, 이 화면은 **뭘 들을지 훑어볼 때** 쓴다.
///
/// - Important: 여기 있는 것이 개설 목록은 아니다. 국가 교육과정의 과목 이름 모음일 뿐이며,
///   실제 개설은 학교마다 다르다. 없는 과목은 폼에서 직접 입력한다.
struct ElectivePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let revision: CurriculumRevision
    let onSelect: (String) -> Void

    @State private var searchText = ""
    /// 제2외국어는 언어를 고르면 회화·심화·문화가 펼쳐진다.
    @State private var expandedLanguage: String?

    private var groups: [ElectiveGroup] {
        CurriculumPreset.electiveGroups(for: revision)
    }

    /// 검색 중이면 교과군 구분 없이 이름만 걸러 보여준다.
    private var searchResults: [String] {
        let query = searchText.trimmed
        guard !query.isEmpty else { return [] }

        let base = CurriculumPreset.suggestedElectiveNames(for: revision)
        let derived = CurriculumPreset.secondLanguages
            .flatMap { CurriculumPreset.secondLanguageDerivedNames(for: $0) }

        return (base + derived)
            .filter { $0.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.trimmed.isEmpty {
                    ForEach(groups) { group in
                        Section(group.subjectArea) {
                            groupContent(group)
                        }
                    }
                } else if searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    Section {
                        ForEach(searchResults, id: \.self) { name in
                            subjectRow(name)
                        }
                    } footer: {
                        Text("찾는 과목이 없으면 이름을 직접 입력하면 됩니다.")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "과목 이름 검색")
            .navigationTitle("과목 고르기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    // MARK: - 교과군 내용

    @ViewBuilder
    private func groupContent(_ group: ElectiveGroup) -> some View {
        if group.subjectArea == "제2외국어" {
            secondLanguageContent(group)
        } else {
            ForEach(ElectiveKind.allCases) { kind in
                let names = group.names(of: kind)
                if !names.isEmpty {
                    // 구분이 하나뿐인 교과군은 라벨을 붙이지 않는다 — 없는 위계를 만들지 않는다.
                    if hasMultipleKinds(group) {
                        Text(kind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(names, id: \.self) { subjectRow($0) }
                }
            }
        }
    }

    private func hasMultipleKinds(_ group: ElectiveGroup) -> Bool {
        ElectiveKind.allCases.filter { !group.names(of: $0).isEmpty }.count > 1
    }

    /// 언어 8개 × 파생 3개를 그대로 펼치면 24줄이 되어 목록이 잠긴다.
    /// 언어를 누르면 그 언어의 파생 과목만 펼친다.
    @ViewBuilder
    private func secondLanguageContent(_ group: ElectiveGroup) -> some View {
        ForEach(group.general, id: \.self) { language in
            subjectRow(language)

            if expandedLanguage == language {
                ForEach(CurriculumPreset.secondLanguageDerivedNames(for: language), id: \.self) { derived in
                    subjectRow(derived, isIndented: true)
                }
            }

            if !CurriculumPreset.secondLanguageDerivedNames(for: language).isEmpty {
                Button {
                    withAnimation {
                        expandedLanguage = (expandedLanguage == language) ? nil : language
                    }
                } label: {
                    Label(
                        expandedLanguage == language ? "접기" : "회화·심화·문화 보기",
                        systemImage: expandedLanguage == language ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
    }

    private func subjectRow(_ name: String, isIndented: Bool = false) -> some View {
        Button {
            onSelect(name)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                if isIndented {
                    Spacer().frame(width: 16)
                }
                Text(verbatim: name)
                Spacer(minLength: 0)
                if isAchievementOnly(name) {
                    // 성취도만 기재하는 과목임을 미리 알려준다. 색이 아니라 텍스트로 표시한다.
                    Text("성취도만")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isAchievementOnly(_ name: String) -> Bool {
        CurriculumPreset.suggestedEvaluationType(
            forSubjectNamed: name, revision: revision
        ) == .achievementOnly
    }
}
