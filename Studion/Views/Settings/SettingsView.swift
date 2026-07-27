import SwiftUI

/// 설정 탭. 8단계에서 `Form` 기반 화면으로 교체된다.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "gearshape",
                title: "설정",
                message: "앱 설정은 다음 단계에서 추가됩니다."
            )
            .navigationTitle("설정")
        }
    }
}

#Preview {
    SettingsView()
}
