import SwiftUI
import SwiftData
import AuthenticationServices

/// 최초 실행 온보딩.
///
/// **로그인을 강제하지 않는다.** 첫 단계에 Apple 로그인을 눈에 잘 보이게 두지만
/// 건너뛸 수 있고, 건너뛰어도 다음 단계로 그냥 넘어간다 — 앱의 모든 기능은
/// 로그인 없이도 로컬로 완전히 동작한다 (원칙: 로그인은 스위치가 아니라 선택).
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppleSignInStore.self) private var signInStore

    @AppStorage(PreferenceKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    @Query private var profiles: [AcademicProfile]

    @State private var step = 0
    @State private var admissionYear = 2025
    @State private var gradeLevel = 1
    @State private var gradingSystem: GradingSystemType = .fiveTier
    @State private var isAddingTimetable = false
    /// Apple 로그인 요청에 실어 보낸 값. 응답을 검증할 때 다시 쓴다 (→ `AppleSignInNonce`).
    @State private var currentNonce: String?

    private let lastStep = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    signInStep.tag(0)
                    academicStep.tag(1)
                    subjectStep.tag(2)
                    timetableStep.tag(3)
                    doneStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                footer
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if step < lastStep {
                        Button("건너뛰기") { finish() }
                    }
                }
            }
        }
    }

    // MARK: - 단계

    private var signInStep: some View {
        stepScaffold(
            icon: "apple.logo",
            title: signInStore.isSignedIn ? "연결됐어요" : "Apple 계정으로 시작할까요?",
            message: signInStore.isSignedIn
                ? "기기를 바꿔도 데이터를 이어서 쓸 수 있어요."
                : "로그인하면 같은 iCloud 계정을 쓰는 다른 기기에서도 이어서 쓸 수 있어요. 지금 건너뛰어도 모든 기능은 그대로 동작합니다."
        ) {
            #if CLOUD_SYNC
            if signInStore.isSignedIn {
                Label("Apple 계정 연결됨", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color("GoalAchieved"))
            } else {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = AppleSignInNonce.random()
                    currentNonce = nonce
                    // 이름은 앱을 통틀어 애플이 딱 한 번만 내려준다. 온보딩이 그 첫 자리이므로
                    // 여기서 받아 팀 메신저 프로필까지 함께 채운다 — 나중에 팀 메신저를 열 때
                    // 또 물어보지 않아도 되게.
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(width: 280, height: 44)
            }
            #else
            Text("이 빌드에는 기기 간 동기화가 포함되어 있지 않아요. 데이터는 이 기기에 저장됩니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            #endif
        }
    }

    private var academicStep: some View {
        stepScaffold(
            icon: "graduationcap",
            title: "학년을 알려주세요",
            message: "입학연도에 맞는 등급제를 제안해 드립니다. 나중에 설정에서 바꿀 수 있어요."
        ) {
            Form {
                Picker("학년", selection: $gradeLevel) {
                    ForEach(1...3, id: \.self) { Text("고\($0)").tag($0) }
                }
                Picker("입학연도", selection: $admissionYear) {
                    ForEach(2020...2030, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                }
                Picker("등급제", selection: $gradingSystem) {
                    ForEach(GradingSystemType.allCases) { Text($0.displayName).tag($0) }
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: admissionYear) { _, year in
                gradingSystem = year >= 2025 ? .fiveTier : .nineTier
            }
        }
    }

    private var subjectStep: some View {
        stepScaffold(
            icon: "book.closed",
            title: "이수 과목은 나중에",
            message: "성적 탭에서 학기를 만들고 과목을 추가하면 됩니다. 지금 정하지 않아도 괜찮아요."
        ) { EmptyView() }
    }

    private var timetableStep: some View {
        stepScaffold(
            icon: "calendar.badge.plus",
            title: "시간표를 등록할까요?",
            message: "학교와 학원 일정을 넣어두면 플래너에서 하루가 한눈에 보입니다."
        ) {
            Button("시간표 추가") { isAddingTimetable = true }
                .buttonStyle(.borderedProminent)
                .sheet(isPresented: $isAddingTimetable) { TimetableFormView() }
        }
    }

    private var doneStep: some View {
        stepScaffold(
            icon: "checkmark.circle",
            title: "준비됐어요",
            message: "비워둔 항목은 언제든 설정에서 채울 수 있습니다."
        ) { EmptyView() }
    }

    // MARK: - 공통

    private func stepScaffold<Content: View>(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            content()

            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        Button(step == lastStep ? "시작하기" : "다음") {
            if step == lastStep {
                finish()
            } else {
                withAnimation { step += 1 }
            }
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding()
    }

    private func finish() {
        // 건너뛰어도 입력한 값까지는 저장한다.
        let profile = profiles.first ?? {
            let created = AcademicProfile()
            context.insert(created)
            return created
        }()

        profile.admissionYear = admissionYear
        profile.gradeLevel = gradeLevel
        profile.gradingSystemType = gradingSystem

        hasCompletedOnboarding = true
    }

    /// Apple 로그인 결과를 두 곳에 반영한다: iCloud 연결 표시(`AppleSignInStore`)와,
    /// 되면 팀 메신저 계정(Supabase)까지. 팀 메신저 쪽은 실패해도 조용히 넘어간다 —
    /// 이 화면의 주된 목적은 iCloud 연결이고, 팀 메신저는 되면 좋은 덤이다. 어차피
    /// 팀 메신저를 실제로 열면 거기서 다시 로그인할 수 있다(→ `DevChatAuthView`).
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result else { return }

        signInStore.handleAuthorization(authorization)

        guard let nonce = currentNonce,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let devChatAuth = DevChatAuthService(client: DevChatClient.shared)
        else { return }

        Task {
            try? await devChatAuth.signInWithApple(idToken: idToken, nonce: nonce, fullName: credential.fullName)
        }
    }
}
