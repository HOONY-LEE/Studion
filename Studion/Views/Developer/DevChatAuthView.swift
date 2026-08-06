import SwiftUI
import AuthenticationServices

/// 로그인 화면. **Apple 계정으로만** 들어온다 — 이메일/비밀번호 가입을 따로 두지 않는다.
///
/// 같은 Apple ID로 다시 눌러도 계정이 새로 생기지 않는다. Apple이 내려주는 고유
/// 식별자로 Supabase가 항상 같은 계정을 찾아 로그인시키기 때문이다 — 회원가입이라는
/// 별도 단계가 없다. → `docs/10-developer-chat.md` §2
///
/// 실명은 보통 여기서가 아니라 **온보딩**에서 이미 채워진다 — 애플은 이름을 정말
/// 최초 한 번만 내려주는데, 온보딩의 Apple 로그인 단계가 앱에서 처음 만나는 자리라
/// 그 기회를 거기서 쓴다(→ `OnboardingView.signInStep`). 온보딩을 건너뛴 사람만
/// 여기서 처음으로 이름을 받게 된다.
struct DevChatAuthView: View {
    let authService: DevChatAuthService

    /// 애플에는 이 값의 해시를 보내고, Supabase에는 원본을 보낸다 — 재사용(replay) 공격을
    /// 막기 위한 값이라 매 로그인 시도마다 새로 만든다.
    @State private var currentNonce: String?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "message.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text(verbatim: "팀 메신저")
                .font(.title2.weight(.semibold))

            Text(verbatim: "Apple 계정으로 로그인하면 팀원들과 바로 대화할 수 있어요.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInNonce.random()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInNonce.sha256(nonce)
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(width: 280, height: 44)
            .disabled(isSubmitting)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .navigationTitle("팀 메신저")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil

        switch result {
        case .failure(let error):
            let nsError = error as NSError
            // 사용자가 시트를 그냥 닫은 것까지 에러로 보여주지 않는다.
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = error.localizedDescription

        case .success(let authorization):
            guard let nonce = currentNonce,
                  let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "로그인 정보를 읽지 못했어요. 다시 시도해주세요."
                return
            }

            isSubmitting = true
            Task {
                defer { isSubmitting = false }
                do {
                    try await authService.signInWithApple(
                        idToken: idToken, nonce: nonce, fullName: credential.fullName
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
