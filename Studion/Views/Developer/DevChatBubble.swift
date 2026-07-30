#if DEBUG
import SwiftUI

/// 말풍선 모서리 — 꼬리 쪽 아래 모서리만 좁혀서(4pt) 꼬리를 표현한다.
///
/// 곡선 꼬리를 따로 그리지 않는 이유는 WorkChat iOS와 같다: 비대칭 모서리가 더 깔끔하고,
/// 경로를 직접 그리면 회전 방향·조절점 때문에 모서리가 파이거나 지느러미처럼 보이는 문제가
/// 생긴다(둘 다 실제로 겪었다). → `docs/10-developer-chat.md` §6
func devChatBubbleCorners(isMine: Bool) -> RectangleCornerRadii {
    RectangleCornerRadii(
        topLeading: 16,
        bottomLeading: isMine ? 16 : 4,
        bottomTrailing: isMine ? 4 : 16,
        topTrailing: 16
    )
}

/// 말풍선 배경색. 내 것은 accent, 받은 것은 중립 회색, 지워진 것은 아주 옅은 회색.
func devChatBubbleBackground(isMine: Bool, isDeleted: Bool) -> Color {
    if isDeleted { return Color.primary.opacity(0.05) }
    return isMine ? Color.accentColor : Color(.secondarySystemBackground)
}

func devChatBubbleForeground(isMine: Bool, isDeleted: Bool) -> Color {
    if isDeleted { return .secondary }
    return isMine ? .white : .primary
}

#Preview {
    VStack(alignment: .trailing, spacing: 6) {
        ForEach([true, false], id: \.self) { isMine in
            Text(verbatim: isMine ? "내가 보낸 말풍선" : "받은 말풍선")
                .foregroundStyle(devChatBubbleForeground(isMine: isMine, isDeleted: false))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(devChatBubbleBackground(isMine: isMine, isDeleted: false))
                .clipShape(.rect(cornerRadii: devChatBubbleCorners(isMine: isMine)))
                .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        }
        Text(verbatim: "삭제된 메시지")
            .italic()
            .foregroundStyle(devChatBubbleForeground(isMine: true, isDeleted: true))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(devChatBubbleBackground(isMine: true, isDeleted: true))
            .clipShape(.rect(cornerRadii: devChatBubbleCorners(isMine: true)))
    }
    .padding()
}
#endif
