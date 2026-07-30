import SwiftUI

/// 앱 최상위 내비게이션. 탭 구성 외의 책임을 갖지 않는다.
/// iPad 대응 시 이 파일의 `TabView`만 `NavigationSplitView`로 교체하면 되도록
/// 각 탭 콘텐츠는 독립 View로 분리해 둔다.
struct RootView: View {
    @AppStorage(PreferenceKey.appearance) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(PreferenceKey.language) private var languageRaw = AppLanguage.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    var body: some View {
        tabs
            // "시스템 설정 따르기"이면 nil이 전달되어 modifier가 적용되지 않은 것과 같아진다.
            .preferredColorScheme(appearance.colorScheme)
            .environment(\.locale, language.locale ?? Locale.autoupdatingCurrent)
    }

    /// 캘린더와 오늘 할 일은 **다른 데이터**라 탭을 나눈다 — 캘린더는 기기의 캘린더 일정,
    /// 오늘 할 일은 앱이 들고 있는 할 일과 시간표다 (Gradin과 같은 구성).
    ///
    /// 팀 메신저는 탭이 아니라 **설정 > 개발자 도구** 안에 있다. 탭바에 두면 학생이 쓰는
    /// 기능처럼 보인다.
    private var tabs: some View {
        TabView {
            CalendarTabView()
                .tabItem { Label("캘린더", systemImage: "calendar") }

            TodayTabView()
                .tabItem { Label("오늘 할 일", systemImage: "checklist") }

            LearnView()
                .tabItem { Label("학습", systemImage: "rectangle.stack") }

            GradesView()
                .tabItem { Label("기록", systemImage: "book.closed") }

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
}
