import Foundation

/// 내신 등급 산출 제도.
enum GradingSystemType: String, Codable, CaseIterable, Identifiable {
    /// 2025년 고1 입학생부터 적용되는 5등급제.
    case fiveTier
    /// 2024년 이전 입학생에게 적용되는 기존 9등급제.
    case nineTier

    var id: String { rawValue }

    /// 등급 경계값 (누적 비율, 오름차순). 마지막 값은 항상 1.0.
    var cumulativeBoundaries: [Double] {
        switch self {
        case .fiveTier:
            return [0.10, 0.34, 0.66, 0.90, 1.00]
        case .nineTier:
            return [0.04, 0.11, 0.23, 0.40, 0.60, 0.77, 0.89, 0.96, 1.00]
        }
    }

    var tierCount: Int { cumulativeBoundaries.count }

    var displayName: String {
        switch self {
        case .fiveTier: String(localized: "5등급제")
        case .nineTier: String(localized: "9등급제")
        }
    }
}

/// 내신 과목의 등급 산출 방식.
enum SchoolSubjectEvaluationType: String, Codable, CaseIterable, Identifiable {
    /// 성취도(A~E) + 석차등급을 함께 기재하는 일반 과목.
    case achievementAndRank
    /// 성취도(A~E)만 기재하는 예외 과목 (사회·과학 융합선택, 체육·예술·교양, 과학탐구실험 등).
    case achievementOnly

    var id: String { rawValue }
}

/// 성취도 등급 (A~E).
enum AchievementLevel: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"

    var id: String { rawValue }
}

/// 오답 원인 태그.
enum WrongAnswerCauseTag: String, Codable, CaseIterable, Identifiable {
    case dontKnow      // 몰라서
    case mistake       // 실수
    case timeShortage  // 시간부족
    case trap          // 함정

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dontKnow: String(localized: "몰라서")
        case .mistake: String(localized: "실수")
        case .timeShortage: String(localized: "시간 부족")
        case .trap: String(localized: "함정")
        }
    }
}

/// 영어 과목 오답노트 하위 카테고리.
enum EnglishSubcategory: String, Codable, CaseIterable, Identifiable {
    case reading, grammar, vocabulary, listening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reading: String(localized: "독해")
        case .grammar: String(localized: "문법")
        case .vocabulary: String(localized: "어휘")
        case .listening: String(localized: "듣기")
        }
    }
}

/// 시간표 항목 유형.
enum TimetableEntryType: String, Codable, CaseIterable, Identifiable {
    case school
    case academy

    var id: String { rawValue }
}
