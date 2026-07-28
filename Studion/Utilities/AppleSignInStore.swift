import Foundation
import AuthenticationServices

/// Sign in with Apple 로그인 상태.
///
/// **이것은 동기화 스위치가 아니다.** 동기화 여부는 기기의 iCloud 계정 유무가 결정한다.
/// 이 상태는 "어떤 Apple ID로 이 앱을 쓰고 있는지"를 사용자에게 보여주기 위한 것이다.
///
/// 로그인하지 않아도 앱의 모든 기능은 로컬로 완전히 동작한다.
@MainActor
@Observable
final class AppleSignInStore {

    private(set) var userIdentifier: String?

    var isSignedIn: Bool { userIdentifier != nil }

    init() {
        userIdentifier = KeychainStore.loadUserIdentifier()
    }

    /// 로그인 성공을 반영한다. 식별자만 보관하고 이메일·이름은 버린다.
    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        KeychainStore.save(userIdentifier: credential.user)
        userIdentifier = credential.user
    }

    func signOut() {
        KeychainStore.clear()
        userIdentifier = nil
    }

    /// 앱 시작 시 자격 증명이 아직 유효한지 확인한다.
    ///
    /// 사용자가 설정에서 앱의 Apple ID 사용을 취소했을 수 있다.
    /// 유효하지 않으면 조용히 로그아웃 상태로 되돌린다 — 기능이 잠기지 않으므로 알릴 필요가 없다.
    func refreshCredentialState() async {
        guard let userIdentifier else { return }

        let provider = ASAuthorizationAppleIDProvider()
        let state = try? await provider.credentialState(forUserID: userIdentifier)

        if state != .authorized {
            signOut()
        }
    }
}
