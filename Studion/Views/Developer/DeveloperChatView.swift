import SwiftUI

/// 개발자 탭 — 개발 기간 동안 팀끼리 쓰는 메신저.
///
/// - Important: 이 탭은 **학생 사용자를 위한 기능이 아니다.** 앱을 출시할 때는
///   빼거나 접근을 막아야 한다. 미성년자 대상 앱에 열린 채팅이 남아 있으면
///   App Store 심사에서 문제가 되고, 이 앱의 원칙(채팅을 만들지 않는다)과도 어긋난다.
///   → `docs/10-developer-chat.md`
struct DeveloperChatView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "bubble.left.and.bubble.right",
                title: "메신저가 아직 연결되지 않았어요",
                message: "Supabase 프로젝트를 연결하면 로그인과 대화를 쓸 수 있습니다."
            )
            .navigationTitle("개발자")
        }
    }
}

#Preview {
    DeveloperChatView()
}
