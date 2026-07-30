#if DEBUG
import SwiftUI

/// 표시 이름의 첫 글자를 담은 원형 아바타. 애플 메시지에서 사진 없는 연락처가 이렇게 보인다.
///
/// 프로필 사진은 범위 밖(→ `docs/10-developer-chat.md` §1)이라 항상 이 모양이다.
/// 색은 중립 회색으로 둔다 — 대화 목록 전체가 accent(빨강)로 뒤덮이지 않게.
struct DevChatAvatar: View {
    let displayName: String
    var diameter: CGFloat = 48
    /// 그룹 대화 표시 — 사람 둘 아이콘으로 바꾼다.
    var isGroup: Bool = false

    var body: some View {
        Circle()
            .fill(Color(.systemGray3))
            .frame(width: diameter, height: diameter)
            .overlay {
                if isGroup {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: diameter * 0.38))
                        .foregroundStyle(.white)
                } else {
                    Text(verbatim: Self.initial(of: displayName))
                        .font(.system(size: diameter * 0.42, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityHidden(true)
    }

    /// 첫 글자 하나. 이름이 비어 있으면 사람 아이콘 대신 물음표를 쓰지 않고 빈 원으로 둔다.
    static func initial(of name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return ""
        }
        return String(first).uppercased()
    }
}

#Preview {
    HStack(spacing: 12) {
        DevChatAvatar(displayName: "이성훈")
        DevChatAvatar(displayName: "taesoon")
        DevChatAvatar(displayName: "", isGroup: true)
        DevChatAvatar(displayName: "이성훈", diameter: 28)
    }
    .padding()
}
#endif
