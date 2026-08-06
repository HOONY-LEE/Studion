import Foundation
import Supabase

/// 개발자 탭의 로그인 상태. Sign in with Apple(`AppleSignInStore`)과는 완전히 별개의
/// 세션이다 — 학생용 CloudKit 계정과 섞이지 않는다. → `docs/10-developer-chat.md` §2
///
/// 로그인은 Apple 계정 하나로만 한다. 이메일/비밀번호 가입을 따로 두면 같은 사람이
/// 계정을 두 번 만들 수 있는데, Apple은 기기의 Apple ID에서 나온 고유 식별자로
/// Supabase가 알아서 같은 계정을 찾아준다 — 회원가입이라는 별도 단계가 필요 없다.
@MainActor
@Observable
final class DevChatAuthService {
    enum State {
        case loading
        case signedOut
        case signedIn(DevProfile)
    }

    private(set) var state: State = .loading
    let client: SupabaseClient
    // deinit은 MainActor에 격리되지 않아 격리된 프로퍼티를 읽을 수 없다.
    // Task 자체는 Sendable이라 이 프로퍼티만 격리를 벗어나도 안전하다.
    nonisolated(unsafe) private var listenTask: Task<Void, Never>?

    /// `client`가 `nil`이면(Supabase 미설정) 이 서비스를 만들지 않는다.
    init?(client: SupabaseClient?) {
        guard let client else { return nil }
        self.client = client
        listenTask = Task { [weak self] in
            await self?.observeAuthChanges()
        }
    }

    deinit {
        listenTask?.cancel()
    }

    private func observeAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                if let session {
                    await loadProfile(userID: session.user.id)
                } else {
                    state = .signedOut
                }
            case .signedOut:
                state = .signedOut
            default:
                break
            }
        }
    }

    private func loadProfile(userID: UUID) async {
        do {
            let profiles: [DevProfile] = try await client
                .from("dev_profiles")
                .select()
                .eq("id", value: userID.uuidString)
                .execute()
                .value
            guard let profile = profiles.first else {
                // 가입 트리거가 아직 프로필을 못 만들었을 수 있다 (타이밍 문제). 로그인 상태는 유지한다.
                return
            }
            state = .signedIn(profile)
        } catch {
            state = .signedOut
        }
    }

    /// Apple 로그인 완료 후 호출한다.
    ///
    /// `fullName`은 애플이 **최초 인증에서만** 내려준다 — 이후 로그인은 항상 `nil`이다.
    /// 그래서 값이 있을 때만 표시 이름을 덮어쓴다. 없으면 가입 트리거가 이메일 앞부분으로
    /// 채워둔 이름이 그대로 남는데, 사용자가 나중에 원하면 직접 고칠 수 있다.
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )

        if let displayName = Self.formattedName(fullName) {
            try await client
                .from("dev_profiles")
                .update(["display_name": displayName])
                .eq("id", value: session.user.id.uuidString)
                .execute()
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    private static func formattedName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default).trimmed
        return formatted.isEmpty ? nil : formatted
    }
}
