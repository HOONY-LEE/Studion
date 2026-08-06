import SwiftUI
import Supabase

/// 프로필 사진 원형 아바타. 사진이 없으면 표시 이름의 첫 글자를 보여준다 —
/// 애플 메시지에서 사진 없는 연락처가 이렇게 보인다.
///
/// 색은 중립 회색으로 둔다 — 대화 목록 전체가 accent(빨강)로 뒤덮이지 않게.
struct DevChatAvatar: View {
    let displayName: String
    var diameter: CGFloat = 48
    /// 그룹 대화 표시 — 사람 둘 아이콘으로 바꾼다.
    var isGroup: Bool = false
    /// 프로필 사진 경로. 있으면 내려받아 보여준다 (→ `DevChatAvatarStore`).
    var avatarPath: String?
    /// 사진을 내려받을 클라이언트. 없으면 첫 글자만 보여준다.
    var client: SupabaseClient?

    @State private var imageData: Data?

    var body: some View {
        Circle()
            .fill(Color(.systemGray3))
            .frame(width: diameter, height: diameter)
            .overlay {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                } else if isGroup {
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
            // 경로가 바뀌면(사진을 새로 올렸으면) 다시 받는다. 새 파일은 이름이 달라진다.
            .task(id: avatarPath) { await loadAvatar() }
    }

    private func loadAvatar() async {
        guard let avatarPath, !avatarPath.isEmpty, let client else {
            imageData = nil
            return
        }
        // 캐시에 있으면 즉시 — 목록을 스크롤할 때마다 깜빡이지 않게.
        if let hit = DevChatAvatarStore.shared.cached(avatarPath) {
            imageData = hit
            return
        }
        imageData = await DevChatAvatarStore.shared.data(for: avatarPath, client: client)
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
