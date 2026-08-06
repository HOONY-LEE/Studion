import SwiftUI

/// 팀끼리 쓰는 메신저. **설정 맨 위**에서 들어간다.
///
/// - Important: **학생 사용자를 위한 기능이 아니다.** 팀원끼리의 연락용으로만 쓴다.
///   → `docs/10-developer-chat.md`
///
/// 설정에서 밀어 넣어 열리므로 **자체 `NavigationStack`을 두지 않는다** — 중첩하면
/// 안쪽 화면들의 툴바와 뒤로가기가 어긋난다.
struct DeveloperChatView: View {
    @State private var authService: DevChatAuthService?

    var body: some View {
        content
            .task {
                if authService == nil {
                    authService = DevChatAuthService(client: DevChatClient.shared)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let authService {
            switch authService.state {
            case .loading:
                ProgressView()
                    .navigationTitle("팀 메신저")

            case .signedOut:
                DevChatAuthView(authService: authService)

            case .signedIn(let profile):
                DevChatRoomListView(authService: authService, profile: profile)
            }
        } else {
            EmptyStateView(
                systemImage: "message",
                title: "메신저가 아직 연결되지 않았어요",
                message: "Supabase 프로젝트를 연결하면 로그인과 대화를 쓸 수 있습니다."
            )
            .navigationTitle("팀 메신저")
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperChatView()
    }
}
