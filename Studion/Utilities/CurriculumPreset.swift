import Foundation

/// 교육과정 개정 구분. 입학연도로 결정된다.
enum CurriculumRevision: String, CaseIterable, Identifiable {
    /// 2015 개정 — 2024년 이전 입학생. 9등급제.
    case revision2015
    /// 2022 개정 — 2025년 이후 입학생. 5등급제.
    case revision2022

    var id: String { rawValue }

    /// 2025년 고1 입학생부터 2022 개정 교육과정이 적용된다.
    static func forAdmissionYear(_ year: Int) -> CurriculumRevision {
        year >= 2025 ? .revision2022 : .revision2015
    }

    var gradingSystem: GradingSystemType {
        switch self {
        case .revision2015: .nineTier
        case .revision2022: .fiveTier
        }
    }

    var displayName: String {
        switch self {
        case .revision2015: String(localized: "2015 개정 교육과정")
        case .revision2022: String(localized: "2022 개정 교육과정")
        }
    }
}

/// 교육과정이 정한 과목 하나의 기본값.
///
/// **이 값은 시작점이지 확정이 아니다.** 학교마다 편성이 다를 수 있으므로
/// 사용자가 언제든 고칠 수 있어야 한다.
struct SubjectPreset: Equatable, Identifiable {
    let name: String
    let creditUnits: Double
    let evaluationType: SchoolSubjectEvaluationType

    var id: String { name }
}

/// 교육과정별 과목 프리셋.
///
/// 순수 Swift로만 구현한다 — SwiftData·SwiftUI를 import하지 않는다.
///
/// ## 근거 자료
/// - 2022 개정: 전북특별자치도교육청 고교학점제지원센터, 「2022 개정 교육과정 고등학교 보통교과」 부록1·2·4
/// - 성취도 산출 규칙: 부산광역시교육청 「2025학년도 고등학교 학업성적관리 시행지침」
///   (교육부훈령 제477호·제504호 근거)
///
/// ## 이 카탈로그가 담는 것과 담지 않는 것
/// - **담는다**: 고1 공통과목. 국가 교육과정이 정한 전국 공통이라 학생마다 다르지 않다.
/// - **담는다**: 석차등급 산출 여부. 학교 재량이 아니라 교육부 훈령이 정한 규칙이다.
/// - **담지 않는다**: 2·3학년 선택과목의 개설 목록. 학교마다 다르므로 이름 추천만 한다
///   (→ `suggestedElectiveNames`).
enum CurriculumPreset {

    // MARK: - 고1 공통과목

    /// 해당 교육과정의 고1 공통과목.
    ///
    /// - Parameter term: 1학기 또는 2학기. 2022 개정은 학기별로 과목이 나뉘어 있다
    ///   (공통국어1 / 공통국어2). 2015 개정은 연간 과목이라 학기와 무관하게 같은 목록을 준다.
    static func commonSubjects(for revision: CurriculumRevision, term: Int) -> [SubjectPreset] {
        switch revision {
        case .revision2022:
            return commonSubjects2022(term: term)
        case .revision2015:
            return commonSubjects2015
        }
    }

    /// 2022 개정 고1 공통과목. 학기제로 나뉘어 1학기는 `1`, 2학기는 `2`가 붙는다.
    private static func commonSubjects2022(term: Int) -> [SubjectPreset] {
        let suffix = term == 2 ? "2" : "1"
        return [
            SubjectPreset(name: "공통국어\(suffix)", creditUnits: 4, evaluationType: .achievementAndRank),
            SubjectPreset(name: "공통수학\(suffix)", creditUnits: 4, evaluationType: .achievementAndRank),
            SubjectPreset(name: "공통영어\(suffix)", creditUnits: 4, evaluationType: .achievementAndRank),
            SubjectPreset(name: "한국사\(suffix)", creditUnits: 3, evaluationType: .achievementAndRank),
            SubjectPreset(name: "통합사회\(suffix)", creditUnits: 4, evaluationType: .achievementAndRank),
            SubjectPreset(name: "통합과학\(suffix)", creditUnits: 4, evaluationType: .achievementAndRank),
            // 과학탐구실험은 3단계 성취도(A·B·C)만 기재하고 석차등급이 나오지 않는다.
            SubjectPreset(name: "과학탐구실험\(suffix)", creditUnits: 1, evaluationType: .achievementOnly),
        ]
    }

    /// 2015 개정 고1 공통과목.
    ///
    /// - Important: 여기 단위는 **연간 기준**이다. 학기당 배분은 학교마다 다르므로
    ///   사용자가 확인하고 고쳐야 한다. UI에서 이 사실을 알린다
    ///   (→ `creditUnitsAreAnnual`).
    private static let commonSubjects2015: [SubjectPreset] = [
        SubjectPreset(name: "국어", creditUnits: 8, evaluationType: .achievementAndRank),
        SubjectPreset(name: "수학", creditUnits: 8, evaluationType: .achievementAndRank),
        SubjectPreset(name: "영어", creditUnits: 8, evaluationType: .achievementAndRank),
        SubjectPreset(name: "한국사", creditUnits: 6, evaluationType: .achievementAndRank),
        SubjectPreset(name: "통합사회", creditUnits: 8, evaluationType: .achievementAndRank),
        SubjectPreset(name: "통합과학", creditUnits: 8, evaluationType: .achievementAndRank),
        SubjectPreset(name: "과학탐구실험", creditUnits: 2, evaluationType: .achievementOnly),
    ]

    /// 이 교육과정의 프리셋 단위가 연간 기준인지.
    ///
    /// 2015 개정은 연간 단위라 학기별로 나눠 쓰려면 사용자가 조정해야 한다.
    /// 2022 개정은 학기별 과목이라 그대로 쓰면 된다.
    static func creditUnitsAreAnnual(for revision: CurriculumRevision) -> Bool {
        revision == .revision2015
    }

    // MARK: - 석차등급이 나오지 않는 과목

    /// 사회·과학 융합선택 9과목 (2022 개정).
    ///
    /// 이 과목들은 A~E 성취도만 기재하고 석차등급이 "·"로 표기된다.
    static let socialScienceFusionElectives2022: [String] = [
        "여행지리",
        "역사로 탐구하는 현대 세계",
        "사회문제 탐구",
        "금융과 경제생활",
        "윤리문제 탐구",
        "기후변화와 지속가능한 세계",
        "과학의 역사와 문화",
        "기후변화와 환경생태",
        "융합과학 탐구",
    ]

    /// 과목명으로 석차등급 산출 여부를 **추정**한다.
    ///
    /// - Important: 이건 힌트이지 판정이 아니다. 최종 결정은 항상 사용자가 한다.
    ///   교육과정이 바뀌거나 학교가 다르게 편성하면 틀릴 수 있다.
    /// - Returns: 성취도만 기재하는 과목으로 보이면 `.achievementOnly`,
    ///   판단할 수 없으면 `nil`.
    static func suggestedEvaluationType(
        forSubjectNamed name: String,
        revision: CurriculumRevision
    ) -> SchoolSubjectEvaluationType? {
        let trimmed = name.trimmed

        if trimmed.hasPrefix("과학탐구실험") {
            return .achievementOnly
        }

        if revision == .revision2022,
           socialScienceFusionElectives2022.contains(trimmed) {
            return .achievementOnly
        }

        return nil
    }

    // MARK: - 선택과목 이름 추천

    /// 2·3학년에서 흔히 쓰이는 과목 이름.
    ///
    /// - Important: **개설 목록이 아니다.** 실제 개설은 학교마다 다르며, 이건 이름을
    ///   매번 타이핑하지 않게 돕는 자동완성 후보일 뿐이다. 여기 없는 과목은 직접 입력한다.
    static func suggestedElectiveNames(for revision: CurriculumRevision) -> [String] {
        switch revision {
        case .revision2022:
            return [
                // 국어
                "화법과 언어", "독서와 작문", "문학",
                // 수학
                "대수", "미적분Ⅰ", "미적분Ⅱ", "확률과 통계", "기하", "경제 수학",
                // 영어
                "영어Ⅰ", "영어Ⅱ", "영미 문학 읽기", "심화 영어",
                // 사회
                "세계시민과 지리", "세계사", "사회와 문화", "현대사회와 윤리",
                "정치", "법과 사회", "경제", "윤리와 사상",
                // 과학
                "물리학", "화학", "생명과학", "지구과학",
                "역학과 에너지", "전자기와 양자", "세포와 물질대사",
            ] + socialScienceFusionElectives2022

        case .revision2015:
            return [
                // 국어
                "화법과 작문", "독서", "언어와 매체", "문학",
                // 수학
                "수학Ⅰ", "수학Ⅱ", "미적분", "확률과 통계", "기하", "실용 수학",
                // 영어
                "영어Ⅰ", "영어Ⅱ", "영어 독해와 작문", "영어 회화",
                // 사회
                "한국지리", "세계지리", "동아시아사", "세계사",
                "경제", "정치와 법", "사회·문화", "생활과 윤리", "윤리와 사상",
                // 과학
                "물리학Ⅰ", "물리학Ⅱ", "화학Ⅰ", "화학Ⅱ",
                "생명과학Ⅰ", "생명과학Ⅱ", "지구과학Ⅰ", "지구과학Ⅱ",
            ]
        }
    }
}
