#if DEBUG
import SwiftUI

/// 로그인/가입 폼. Sign in with Apple 화면과 다르게, 이건 개발자 탭 전용의
/// 완전히 별도 세션이다 (→ `docs/10-developer-chat.md` §2).
struct DevChatAuthView: View {
    let authService: DevChatAuthService

    private enum Mode: Hashable {
        case signIn, signUp
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !email.trimmed.isEmpty && !password.isEmpty && (mode == .signIn || !displayName.trimmed.isEmpty)
    }

    var body: some View {
        Form {
            Section {
                Picker("모드", selection: $mode) {
                    Text("로그인").tag(Mode.signIn)
                    Text("가입").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                TextField("이메일", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("비밀번호", text: $password)
                if mode == .signUp {
                    TextField("표시 이름", text: $displayName)
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }

            Section {
                Button(mode == .signIn ? "로그인" : "가입하기") {
                    submit()
                }
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .navigationTitle("개발자")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                switch mode {
                case .signIn:
                    try await authService.signIn(email: email.trimmed, password: password)
                case .signUp:
                    try await authService.signUp(
                        email: email.trimmed, password: password, displayName: displayName.trimmed
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif
