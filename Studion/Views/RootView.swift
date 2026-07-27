import SwiftUI

/// 앱 최상위 내비게이션. 탭 구성 외의 책임을 갖지 않는다.
/// iPad 대응 시 이 파일의 `TabView`만 `NavigationSplitView`로 교체하면 되도록
/// 각 탭 콘텐츠는 독립 View로 분리해 둔다.
struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("오늘", systemImage: "house") }

            PlannerView()
                .tabItem { Label("플래너", systemImage: "calendar") }

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
