import SwiftUI
import AuthenticationServices

/// 설정 탭. 8단계에서 나머지 섹션이 채워진다.
struct SettingsView: View {
    @Environment(AppleSignInStore.self) private var signInStore
    @Environment(CloudAccountStatus.self) private var cloudStatus

    @State private var isConfirmingSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                syncSection
            }
            .navigationTitle("설정")
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        Section {
            LabeledContent("동기화 상태") {
                Text(cloudStatus.state.summary)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }

            if signInStore.isSignedIn {
                LabeledContent("Apple 계정") {
                    Label("연결됨", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color("GoalAchieved"))
                }
                Button("연결 해제") { isConfirmingSignOut = true }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    // 이메일·이름을 요청하지 않는다. 필요한 것은 식별자뿐이다.
                    request.requestedScopes = []
                } onCompletion: { result in
                    if case .success(let authorization) = result {
                        signInStore.handleAuthorization(authorization)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .listRowInsets(EdgeInsets())
            }
        } header: {
            Text("기기 간 데이터")
        } footer: {
            Text("""
                기기를 바꿔도 데이터를 유지하려면 같은 iCloud 계정을 쓰세요. \
                로그인하지 않아도 모든 기능은 이 기기에서 그대로 동작합니다. \
                저장된 내용은 본인의 iCloud에만 보관되며 개발자가 볼 수 없습니다.
                """)
        }
        .confirmationDialog(
            "Apple 계정 연결을 해제할까요?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("연결 해제") { signInStore.signOut() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 기기의 데이터는 지워지지 않습니다.")
        }
    }
}
