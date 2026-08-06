import SwiftUI
import Supabase

/// 대화 상대 프로필 — 말풍선 옆 아바타를 누르면 아래에서 올라온다.
///
/// 보기 전용이다. 남의 프로필을 여기서 고칠 수 없고, 내 프로필은 설정에서 바꾼다
/// (→ `DevChatProfileView`). 그래서 버튼 없이 사진·이름·이메일만 보여준다.
struct DevChatMemberSheet: View {
    let member: DevProfile
    let client: SupabaseClient

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DevChatAvatar(
                    displayName: member.displayName,
                    diameter: 108,
                    avatarPath: member.avatarPath,
                    client: client
                )
                .padding(.top, 24)

                VStack(spacing: 6) {
                    Text(verbatim: member.displayName)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)

                    // 이메일은 없을 수 있다 — Apple 계정에서 가리기를 골랐거나 옛 계정이면 비어 있다.
                    if let email = member.email, !email.isEmpty {
                        Text(verbatim: email)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}
