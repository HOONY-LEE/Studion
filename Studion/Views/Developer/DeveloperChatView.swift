#if DEBUG
import SwiftUI

/// 개발 기간 동안 팀끼리 쓰는 메신저. **설정 > 개발자 도구** 안에 있다.
///
/// - Important: **학생 사용자를 위한 기능이 아니다.** 파일 전체를 `#if DEBUG`로 감싸
///   Release(App Store 제출본)에는 이 타입 자체가 컴파일되지 않는다 — 화면을 안 보여주는
///   것만으로는 부족하다(별도 컴파일 단위라 그것만으로는 Release 빌드에서 여전히
///   컴파일된다). 미성년자 대상 앱에 채팅이 남아 있으면 App Store 심사에서 문제가 되고,
///   이 앱의 원칙(채팅을 만들지 않는다)과도 어긋난다.
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

            case .awaitingEmailConfirmation:
                EmptyStateView(
                    systemImage: "envelope.badge",
                    title: "이메일을 확인해주세요",
                    message: "가입한 이메일로 온 확인 링크를 눌러야 로그인할 수 있어요."
                )
                .navigationTitle("팀 메신저")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("로그인 화면으로") {
                            authService.returnToSignIn()
                        }
                    }
                }

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
#endif
