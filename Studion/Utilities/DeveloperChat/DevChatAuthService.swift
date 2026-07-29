#if DEBUG
import Foundation
import Supabase

/// 개발자 탭의 로그인 상태. Sign in with Apple(`AppleSignInStore`)과는 완전히 별개의
/// 세션이다 — 학생용 CloudKit 계정과 섞이지 않는다. → `docs/10-developer-chat.md` §2
@MainActor
@Observable
final class DevChatAuthService {
    enum State {
        case loading
        case signedOut
        /// 가입 직후 이메일 확인이 필요한 경우 (Supabase 프로젝트 설정에 따라 다르다).
        case awaitingEmailConfirmation
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

    func signUp(email: String, password: String, displayName: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )
        if response.session == nil {
            state = .awaitingEmailConfirmation
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// 이메일 확인 대기 화면에서 로그인 화면으로 되돌아간다.
    func returnToSignIn() {
        state = .signedOut
    }
}
#endif
