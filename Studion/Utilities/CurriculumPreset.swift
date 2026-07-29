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

/// 선택과목의 구분. 2022 개정은 셋으로 나뉘고, 2015 개정은 일반/진로 둘뿐이다.
enum ElectiveKind: String, CaseIterable, Identifiable {
    case general   // 일반 선택 — 학문별 주요 내용
    case career    // 진로 선택 — 심화
    case fusion    // 융합 선택 — 교과 융합, 실생활 응용

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: String(localized: "일반 선택")
        case .career: String(localized: "진로 선택")
        case .fusion: String(localized: "융합 선택")
        }
    }
}

/// 한 교과(군)의 선택과목 묶음.
struct ElectiveGroup: Equatable, Identifiable {
    /// 교과(군) 이름. 예: "국어", "사회(역사/도덕 포함)"
    let subjectArea: String
    let general: [String]
    let career: [String]
    let fusion: [String]

    var id: String { subjectArea }

    func names(of kind: ElectiveKind) -> [String] {
        switch kind {
        case .general: general
        case .career: career
        case .fusion: fusion
        }
    }

    var allNames: [String] { general + career + fusion }
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

        // 체육·예술·교양 교과는 두 교육과정 모두 석차등급을 내지 않는다.
        if achievementOnlySubjectAreas.contains(where: { area in
            electiveGroups(for: revision)
                .first { $0.subjectArea == area }?
                .allNames.contains(trimmed) ?? false
        }) {
            return .achievementOnly
        }

        return nil
    }

    /// 교과 전체가 성취도만 기재하는 교과(군).
    ///
    /// 교육부 훈령상 체육·예술·교양은 석차등급을 산출하지 않는다.
    private static let achievementOnlySubjectAreas: Set<String> = ["체육", "예술", "교양"]

    // MARK: - 선택과목 카탈로그

    /// 2·3학년 선택과목을 교과(군)별로 묶은 목록.
    ///
    /// - Important: **개설 목록이 아니다.** 국가 교육과정이 정한 과목 이름의 모음일 뿐이고,
    ///   실제로 어떤 과목이 열리는지는 학교마다 다르다. 여기 없는 과목은 직접 입력한다.
    static func electiveGroups(for revision: CurriculumRevision) -> [ElectiveGroup] {
        switch revision {
        case .revision2022: electiveGroups2022
        case .revision2015: electiveGroups2015
        }
    }

    /// 자동완성용 평면 목록. 교과군 구분 없이 이름만 필요할 때 쓴다.
    static func suggestedElectiveNames(for revision: CurriculumRevision) -> [String] {
        electiveGroups(for: revision).flatMap(\.allNames)
    }

    /// 2022 개정 교육과정 보통교과 선택과목 (교육과정 총론 <표5>).
    ///
    /// 제2외국어는 8개 언어가 각각 회화·심화·문화 과목을 갖는데, 그대로 펼치면
    /// 30개가 넘어 목록이 잠긴다. 그래서 언어 기본 과목만 싣고 파생 과목은
    /// `secondLanguageDerivedNames(for:)`로 따로 만든다.
    private static let electiveGroups2022: [ElectiveGroup] = [
        ElectiveGroup(
            subjectArea: "국어",
            general: ["화법과 언어", "독서와 작문", "문학"],
            career: ["주제 탐구 독서", "문학과 영상", "직무 의사소통"],
            fusion: ["독서 토론과 글쓰기", "매체 의사소통", "언어생활 탐구"]
        ),
        ElectiveGroup(
            subjectArea: "수학",
            general: ["대수", "미적분Ⅰ", "확률과 통계"],
            career: ["기하", "미적분Ⅱ", "경제 수학", "인공지능 수학", "직무 수학"],
            fusion: ["수학과 문화", "실용 통계", "수학과제 탐구"]
        ),
        ElectiveGroup(
            subjectArea: "영어",
            general: ["영어Ⅰ", "영어Ⅱ", "영어 독해와 작문"],
            career: [
                "영미 문학 읽기", "영어 발표와 토론", "심화 영어",
                "심화 영어 독해와 작문", "직무 영어",
            ],
            fusion: ["실생활 영어 회화", "미디어 영어", "세계 문화와 영어"]
        ),
        ElectiveGroup(
            subjectArea: "사회(역사/도덕 포함)",
            general: ["세계시민과 지리", "세계사", "사회와 문화", "현대사회와 윤리"],
            career: [
                "한국지리 탐구", "도시의 미래 탐구", "동아시아 역사 기행",
                "정치", "법과 사회", "경제", "윤리와 사상",
                "인문학과 윤리", "국제 관계의 이해",
            ],
            fusion: [
                "여행지리", "역사로 탐구하는 현대 세계", "사회문제 탐구",
                "금융과 경제생활", "윤리문제 탐구", "기후변화와 지속가능한 세계",
            ]
        ),
        ElectiveGroup(
            subjectArea: "과학",
            general: ["물리학", "화학", "생명과학", "지구과학"],
            career: [
                "역학과 에너지", "전자기와 양자", "물질과 에너지", "화학 반응의 세계",
                "세포와 물질대사", "생물의 유전", "지구시스템과학", "행성우주과학",
            ],
            fusion: ["과학의 역사와 문화", "기후변화와 환경생태", "융합과학 탐구"]
        ),
        ElectiveGroup(
            subjectArea: "체육",
            general: ["체육1", "체육2"],
            career: ["운동과 건강", "스포츠 문화", "스포츠 과학"],
            fusion: ["스포츠 생활1", "스포츠 생활2"]
        ),
        ElectiveGroup(
            subjectArea: "예술",
            general: ["음악", "미술", "연극"],
            career: [
                "음악 연주와 창작", "음악 감상과 비평",
                "미술 창작", "미술 감상과 비평",
            ],
            fusion: ["음악과 미디어", "미술과 매체"]
        ),
        ElectiveGroup(
            subjectArea: "기술·가정",
            general: ["기술·가정"],
            career: ["로봇과 공학세계", "생활과학 탐구"],
            fusion: [
                "창의 공학 설계", "지식 재산 일반",
                "생애 설계와 자립", "아동발달과 부모",
            ]
        ),
        ElectiveGroup(
            subjectArea: "정보",
            general: ["정보"],
            career: ["인공지능 기초", "데이터 과학"],
            fusion: ["소프트웨어와 생활"]
        ),
        ElectiveGroup(
            subjectArea: "제2외국어",
            general: secondLanguages,
            career: [],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "한문",
            general: ["한문"],
            career: ["한문 고전 읽기"],
            fusion: ["언어생활과 한자"]
        ),
        ElectiveGroup(
            subjectArea: "교양",
            general: ["진로와 직업", "생태와 환경"],
            career: [
                "인간과 철학", "논리와 사고", "인간과 심리",
                "교육의 이해", "삶과 종교", "보건",
            ],
            fusion: ["인간과 경제활동", "논술"]
        ),
    ]

    /// 2022 개정 제2외국어 8개 언어.
    static let secondLanguages: [String] = [
        "독일어", "프랑스어", "스페인어", "중국어",
        "일본어", "러시아어", "아랍어", "베트남어",
    ]

    /// 한 언어의 파생 과목 이름 (회화·심화·문화).
    ///
    /// "중국 문화"처럼 어미가 불규칙한 경우가 있어 표로 둔다 —
    /// 규칙으로 만들면 "중국어 문화" 같은 없는 이름이 생긴다.
    static func secondLanguageDerivedNames(for language: String) -> [String] {
        let cultureName: String
        switch language {
        case "독일어": cultureName = "독일어권 문화"
        case "프랑스어": cultureName = "프랑스어권 문화"
        case "스페인어": cultureName = "스페인어권 문화"
        case "중국어": cultureName = "중국 문화"
        case "일본어": cultureName = "일본 문화"
        case "러시아어": cultureName = "러시아 문화"
        case "아랍어": cultureName = "아랍 문화"
        case "베트남어": cultureName = "베트남 문화"
        default: return []
        }
        return ["\(language) 회화", "심화 \(language)", cultureName]
    }

    /// 2015 개정 교육과정 보통교과 선택과목.
    ///
    /// 2015 개정에는 융합 선택 구분이 없다 — 일반 선택과 진로 선택 둘뿐이다.
    private static let electiveGroups2015: [ElectiveGroup] = [
        ElectiveGroup(
            subjectArea: "국어",
            general: ["화법과 작문", "독서", "언어와 매체", "문학"],
            career: ["실용 국어", "심화 국어", "고전 읽기"],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "수학",
            general: ["수학Ⅰ", "수학Ⅱ", "미적분", "확률과 통계"],
            career: ["실용 수학", "기하", "경제 수학", "수학과제 탐구"],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "영어",
            general: ["영어 회화", "영어Ⅰ", "영어 독해와 작문", "영어Ⅱ"],
            career: ["실용 영어", "영어권 문화", "진로 영어", "영미 문학 읽기"],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "사회(역사/도덕 포함)",
            general: [
                "한국지리", "세계지리", "세계사", "동아시아사",
                "경제", "정치와 법", "사회·문화", "생활과 윤리", "윤리와 사상",
            ],
            career: ["여행지리", "사회문제 탐구", "고전과 윤리"],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "과학",
            general: ["물리학Ⅰ", "화학Ⅰ", "생명과학Ⅰ", "지구과학Ⅰ"],
            career: [
                "물리학Ⅱ", "화학Ⅱ", "생명과학Ⅱ", "지구과학Ⅱ",
                "과학사", "생활과 과학", "융합과학",
            ],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "체육",
            general: ["체육", "운동과 건강"],
            career: ["스포츠 생활", "체육 탐구"],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "예술",
            general: ["음악", "미술", "연극"],
            career: ["음악 연주", "음악 감상과 비평", "미술 창작", "미술 감상과 비평"],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "기술·가정",
            general: ["기술·가정", "정보"],
            career: [
                "농업 생명 과학", "공학 일반", "창의 경영", "해양 문화와 기술",
                "가정과학", "지식 재산 일반", "인공지능 기초",
            ],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "제2외국어",
            general: secondLanguages.map { "\($0)Ⅰ" },
            career: secondLanguages.map { "\($0)Ⅱ" },
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "한문",
            general: ["한문Ⅰ"],
            career: ["한문Ⅱ"],
            fusion: []
        ),
        ElectiveGroup(
            subjectArea: "교양",
            general: [
                "철학", "논리학", "심리학", "교육학",
                "종교학", "진로와 직업", "보건", "환경", "실용 경제", "논술",
            ],
            career: [],
            fusion: []
        ),
    ]
}
