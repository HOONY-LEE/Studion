import Foundation
import Testing
@testable import Studion

@Suite("교육과정 개정 판정")
struct CurriculumRevisionTests {

    @Test("2025년 입학부터 2022 개정", arguments: [2025, 2026, 2030])
    func newRevision(year: Int) {
        #expect(CurriculumRevision.forAdmissionYear(year) == .revision2022)
    }

    @Test("2024년 이전 입학은 2015 개정", arguments: [2020, 2023, 2024])
    func oldRevision(year: Int) {
        #expect(CurriculumRevision.forAdmissionYear(year) == .revision2015)
    }

    @Test("개정별 등급제가 맞다")
    func gradingSystemMatchesRevision() {
        #expect(CurriculumRevision.revision2022.gradingSystem == .fiveTier)
        #expect(CurriculumRevision.revision2015.gradingSystem == .nineTier)
    }

    @Test("입학연도로 정한 등급제가 설정 화면의 제안과 일치한다")
    func consistentWithProfileSuggestion() {
        // 설정 화면은 admissionYear >= 2025 → fiveTier를 제안한다. 같은 기준이어야 한다.
        #expect(CurriculumRevision.forAdmissionYear(2025).gradingSystem == .fiveTier)
        #expect(CurriculumRevision.forAdmissionYear(2024).gradingSystem == .nineTier)
    }
}

@Suite("고1 공통과목 프리셋")
struct CommonSubjectsTests {

    @Test("2022 개정 1학기는 과목명에 1이 붙는다")
    func revision2022FirstTerm() {
        let subjects = CurriculumPreset.commonSubjects(for: .revision2022, term: 1)
        let names = subjects.map(\.name)
        #expect(names.contains("공통국어1"))
        #expect(names.contains("과학탐구실험1"))
        #expect(!names.contains("공통국어2"))
    }

    @Test("2022 개정 2학기는 과목명에 2가 붙는다")
    func revision2022SecondTerm() {
        let names = CurriculumPreset.commonSubjects(for: .revision2022, term: 2).map(\.name)
        #expect(names.contains("공통국어2"))
        #expect(names.contains("과학탐구실험2"))
        #expect(!names.contains("공통국어1"))
    }

    @Test("2022 개정 공통과목은 7개다")
    func revision2022Count() {
        #expect(CurriculumPreset.commonSubjects(for: .revision2022, term: 1).count == 7)
    }

    @Test("2015 개정은 학기와 무관하게 같은 목록이다")
    func revision2015IsTermIndependent() {
        let first = CurriculumPreset.commonSubjects(for: .revision2015, term: 1)
        let second = CurriculumPreset.commonSubjects(for: .revision2015, term: 2)
        #expect(first == second)
    }

    @Test("2015 개정 공통과목 이름에는 학기 숫자가 붙지 않는다")
    func revision2015HasNoTermSuffix() {
        let names = CurriculumPreset.commonSubjects(for: .revision2015, term: 1).map(\.name)
        #expect(names.contains("국어"))
        #expect(names.contains("과학탐구실험"))
        #expect(!names.contains("공통국어1"))
    }

    @Test("과학탐구실험은 두 교육과정 모두 성취도만 기재한다")
    func scienceLabIsAchievementOnly() {
        for revision in CurriculumRevision.allCases {
            let subjects = CurriculumPreset.commonSubjects(for: revision, term: 1)
            let lab = subjects.first { $0.name.hasPrefix("과학탐구실험") }
            #expect(lab?.evaluationType == .achievementOnly)
        }
    }

    @Test("과학탐구실험을 뺀 공통과목은 석차등급이 나온다")
    func otherCommonSubjectsHaveRank() {
        for revision in CurriculumRevision.allCases {
            let others = CurriculumPreset.commonSubjects(for: revision, term: 1)
                .filter { !$0.name.hasPrefix("과학탐구실험") }
            #expect(others.allSatisfy { $0.evaluationType == .achievementAndRank })
        }
    }

    @Test("모든 프리셋의 이수단위는 양수다")
    func creditUnitsArePositive() {
        for revision in CurriculumRevision.allCases {
            for term in [1, 2] {
                let subjects = CurriculumPreset.commonSubjects(for: revision, term: term)
                #expect(subjects.allSatisfy { $0.creditUnits > 0 })
            }
        }
    }

    @Test("2015 개정만 연간 단위 표시가 필요하다")
    func annualCreditFlag() {
        #expect(CurriculumPreset.creditUnitsAreAnnual(for: .revision2015))
        #expect(!CurriculumPreset.creditUnitsAreAnnual(for: .revision2022))
    }
}

@Suite("평가 방식 추정")
struct EvaluationTypeSuggestionTests {

    @Test("과학탐구실험은 학기 숫자가 붙어도 성취도만으로 본다", arguments: [
        "과학탐구실험", "과학탐구실험1", "과학탐구실험2",
    ])
    func scienceLabVariants(name: String) {
        #expect(
            CurriculumPreset.suggestedEvaluationType(forSubjectNamed: name, revision: .revision2022)
                == .achievementOnly
        )
    }

    @Test("사회·과학 융합선택 9과목은 2022 개정에서 성취도만이다")
    func fusionElectives() {
        for name in CurriculumPreset.socialScienceFusionElectives2022 {
            #expect(
                CurriculumPreset.suggestedEvaluationType(forSubjectNamed: name, revision: .revision2022)
                    == .achievementOnly
            )
        }
    }

    @Test("융합선택 규칙은 2015 개정에 적용되지 않는다")
    func fusionRuleIsRevisionSpecific() {
        // 2015 개정에는 이 분류 자체가 없다. 진로선택 전체가 다른 규칙을 따른다.
        #expect(
            CurriculumPreset.suggestedEvaluationType(forSubjectNamed: "여행지리", revision: .revision2015)
                == nil
        )
    }

    @Test("앞뒤 공백이 있어도 인식한다")
    func trimsWhitespace() {
        #expect(
            CurriculumPreset.suggestedEvaluationType(forSubjectNamed: "  여행지리  ", revision: .revision2022)
                == .achievementOnly
        )
    }

    @Test("모르는 과목은 nil을 돌려준다 — 앱이 단정하지 않는다")
    func unknownSubjectReturnsNil() {
        #expect(
            CurriculumPreset.suggestedEvaluationType(forSubjectNamed: "학교자율과목", revision: .revision2022)
                == nil
        )
        #expect(
            CurriculumPreset.suggestedEvaluationType(forSubjectNamed: "미적분", revision: .revision2022)
                == nil
        )
    }
}

@Suite("선택과목 이름 추천")
struct ElectiveSuggestionTests {

    @Test("개정별로 다른 목록을 준다")
    func differsByRevision() {
        let new = CurriculumPreset.suggestedElectiveNames(for: .revision2022)
        let old = CurriculumPreset.suggestedElectiveNames(for: .revision2015)
        #expect(new != old)
    }

    @Test("2022 개정 추천에는 융합선택 9과목이 포함된다")
    func includesFusionElectives() {
        let names = CurriculumPreset.suggestedElectiveNames(for: .revision2022)
        for fusion in CurriculumPreset.socialScienceFusionElectives2022 {
            #expect(names.contains(fusion))
        }
    }

    @Test("추천 목록에 중복이 없다")
    func noDuplicates() {
        for revision in CurriculumRevision.allCases {
            let names = CurriculumPreset.suggestedElectiveNames(for: revision)
            #expect(Set(names).count == names.count)
        }
    }

    @Test("추천 목록이 비어 있지 않다")
    func notEmpty() {
        for revision in CurriculumRevision.allCases {
            #expect(!CurriculumPreset.suggestedElectiveNames(for: revision).isEmpty)
        }
    }
}

// MARK: - 선택과목 카탈로그

@Suite("선택과목 카탈로그")
struct ElectiveCatalogTests {

    @Test("두 교육과정 모두 교과군이 충분히 들어 있다")
    func hasSubjectAreas() {
        for revision in CurriculumRevision.allCases {
            let groups = CurriculumPreset.electiveGroups(for: revision)
            #expect(groups.count >= 10, "\(revision) 교과군이 부족합니다")

            let areas = groups.map(\.subjectArea)
            for expected in ["국어", "수학", "영어", "과학", "체육", "예술", "교양"] {
                #expect(areas.contains(expected), "\(revision)에 \(expected) 교과군이 없습니다")
            }
        }
    }

    @Test("교과군 이름이 중복되지 않는다")
    func subjectAreasAreUnique() {
        for revision in CurriculumRevision.allCases {
            let areas = CurriculumPreset.electiveGroups(for: revision).map(\.subjectArea)
            #expect(Set(areas).count == areas.count)
        }
    }

    @Test("모든 교과군에 과목이 하나 이상 있다")
    func everyGroupHasSubjects() {
        for revision in CurriculumRevision.allCases {
            for group in CurriculumPreset.electiveGroups(for: revision) {
                #expect(!group.allNames.isEmpty, "\(group.subjectArea)가 비어 있습니다")
            }
        }
    }

    @Test("과목명 앞뒤에 공백이 없다")
    func namesAreTrimmed() {
        for revision in CurriculumRevision.allCases {
            for name in CurriculumPreset.suggestedElectiveNames(for: revision) {
                #expect(name == name.trimmingCharacters(in: .whitespacesAndNewlines), "'\(name)'")
            }
        }
    }

    @Test("2022 개정에는 융합 선택이 있고, 2015 개정에는 없다")
    func fusionOnlyIn2022() {
        let fusion2022 = CurriculumPreset.electiveGroups(for: .revision2022)
            .flatMap { $0.names(of: .fusion) }
        #expect(!fusion2022.isEmpty)

        let fusion2015 = CurriculumPreset.electiveGroups(for: .revision2015)
            .flatMap { $0.names(of: .fusion) }
        #expect(fusion2015.isEmpty, "2015 개정에는 융합 선택 구분이 없습니다")
    }

    @Test("2022 개정 사회·과학 융합선택 9과목이 카탈로그에 있다")
    func fusionElectivesArePresent() {
        let names = CurriculumPreset.suggestedElectiveNames(for: .revision2022)
        for subject in CurriculumPreset.socialScienceFusionElectives2022 {
            #expect(names.contains(subject), "'\(subject)'가 카탈로그에 없습니다")
        }
    }

    @Test("사회·과학 융합선택은 성취도만 기재로 추정된다")
    func fusionElectivesAreAchievementOnly() {
        for subject in CurriculumPreset.socialScienceFusionElectives2022 {
            #expect(
                CurriculumPreset.suggestedEvaluationType(
                    forSubjectNamed: subject, revision: .revision2022
                ) == .achievementOnly
            )
        }
    }

    @Test("체육·예술·교양 과목은 성취도만 기재로 추정된다", arguments: [
        "체육1", "스포츠 문화", "음악", "미술 창작", "진로와 직업", "논술",
    ])
    func peArtLiberalAreAchievementOnly(subject: String) {
        #expect(
            CurriculumPreset.suggestedEvaluationType(
                forSubjectNamed: subject, revision: .revision2022
            ) == .achievementOnly
        )
    }

    @Test("일반 교과 선택과목은 판단을 보류한다 — 앱이 단정하지 않는다", arguments: [
        "대수", "미적분Ⅰ", "물리학", "세계사", "문학",
    ])
    func regularSubjectsReturnNil(subject: String) {
        #expect(
            CurriculumPreset.suggestedEvaluationType(
                forSubjectNamed: subject, revision: .revision2022
            ) == nil
        )
    }

    @Test("제2외국어 8개 언어가 모두 있다")
    func hasAllSecondLanguages() {
        #expect(CurriculumPreset.secondLanguages.count == 8)
        let names = CurriculumPreset.suggestedElectiveNames(for: .revision2022)
        for language in CurriculumPreset.secondLanguages {
            #expect(names.contains(language))
        }
    }

    @Test("제2외국어 파생 과목은 회화·심화·문화 셋이다")
    func derivedNamesShape() {
        for language in CurriculumPreset.secondLanguages {
            let derived = CurriculumPreset.secondLanguageDerivedNames(for: language)
            #expect(derived.count == 3, "\(language)")
            #expect(derived[0] == "\(language) 회화")
            #expect(derived[1] == "심화 \(language)")
        }
    }

    @Test("문화 과목 이름의 불규칙 어미를 지킨다", arguments: [
        ("중국어", "중국 문화"),
        ("일본어", "일본 문화"),
        ("독일어", "독일어권 문화"),
        ("프랑스어", "프랑스어권 문화"),
        ("베트남어", "베트남 문화"),
    ])
    func cultureNamesAreIrregular(language: String, expected: String) {
        let derived = CurriculumPreset.secondLanguageDerivedNames(for: language)
        #expect(derived.contains(expected), "\(language) → \(expected)")
    }

    @Test("모르는 언어에는 빈 배열을 준다")
    func unknownLanguageReturnsEmpty() {
        #expect(CurriculumPreset.secondLanguageDerivedNames(for: "이탈리아어").isEmpty)
    }
}
