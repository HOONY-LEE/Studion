import SwiftUI

/// 앱 모양(라이트/다크/시스템).
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "시스템 설정")
        case .light: String(localized: "라이트")
        case .dark: String(localized: "다크")
        }
    }

    /// `.system`일 때 `nil`을 돌려준다.
    ///
    /// 호출부는 이 값을 `.preferredColorScheme`에 그대로 넘긴다 —
    /// `nil`이면 modifier가 적용되지 않은 것과 같아 시스템 설정을 그대로 따른다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// 앱 표시 언어. 시스템 언어와 별개로 강제 전환할 수 있다.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, korean, english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "시스템 설정")
        case .korean: String(localized: "한국어")
        case .english: String(localized: "English")
        }
    }

    /// `.system`이면 `nil` — 환경 로케일을 덮어쓰지 않는다.
    var locale: Locale? {
        switch self {
        case .system: nil
        case .korean: Locale(identifier: "ko_KR")
        case .english: Locale(identifier: "en_US")
        }
    }
}

/// `@AppStorage` 키를 한곳에 모은다.
enum PreferenceKey {
    static let appearance = "preference.appearance"
    static let language = "preference.language"
    static let hasCompletedOnboarding = "preference.hasCompletedOnboarding"
    static let planReminderEnabled = "preference.planReminderEnabled"
    static let planReminderHour = "preference.planReminderHour"
    static let planReminderMinute = "preference.planReminderMinute"
    static let reviewReminderEnabled = "preference.reviewReminderEnabled"
    /// 학교 일과표(교시 시각·수업 길이·점심·교시 수)를 JSON 한 덩어리로 담는다.
    /// 항목이 여러 개라 키를 하나씩 두지 않는다 — 항목을 늘려도 저장 코드가 그대로다.
    /// → `SchoolPeriodSchedule`
    static let periodSchedule = "preference.periodSchedule"
}
