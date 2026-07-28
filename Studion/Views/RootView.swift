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

    private var tabs: some View {
        TabView {
            TodayView()
                .tabItem { Label("오늘", systemImage: "house") }

            PlannerView()
                .tabItem { Label("플래너", systemImage: "calendar") }

            LearnView()
                .tabItem { Label("학습", systemImage: "rectangle.stack") }

            GradesView()
                .tabItem { Label("성적", systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
}
