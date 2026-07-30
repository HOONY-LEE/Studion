#if DEBUG
import SwiftUI

/// 애플 메시지 말풍선 모양. 묶음의 마지막 말풍선에만 꼬리가 붙는다.
///
/// 꼬리 폭만큼 본체를 안쪽으로 들여서 그린다 — 그러지 않으면 꼬리가 뷰 경계를 넘어
/// 잘린다. 그래서 이 모양을 쓰는 쪽은 꼬리 방향으로 `tailWidth`만큼 여백을 준 셈이 된다.
struct DevChatBubbleShape: Shape {
    /// 내 메시지인가 (꼬리가 오른쪽에 붙는다).
    let isMine: Bool
    let hasTail: Bool

    var cornerRadius: CGFloat = 18
    static let tailWidth: CGFloat = 6
    /// 꼬리가 본체 옆면에서 갈라져 나오는 높이.
    private var tailHeight: CGFloat { 15 }
    /// 꼬리 끝에서 본체 밑면으로 감아 들어오는 거리.
    private var tailReturn: CGFloat { 10 }

    func path(in rect: CGRect) -> Path {
        let inset = Self.tailWidth
        let body = CGRect(
            x: isMine ? rect.minX : rect.minX + inset,
            y: rect.minY,
            width: rect.width - inset,
            height: rect.height
        )
        let radius = min(cornerRadius, min(body.width, body.height) / 2)

        // 왼쪽 위에서 시작해 **시계 방향으로 한 바퀴** 도는 하나의 외곽선을 만든다.
        //
        // 본체와 꼬리를 각각 따로 그려 겹치면 안 된다 — 두 하위 경로의 회전 방향이
        // 어긋나면 채우기 규칙(nonzero winding)이 겹친 부분을 **구멍으로 판단**해
        // 말풍선 모서리가 파인 것처럼 보인다. 좌우가 거울상이라 한쪽만 그렇게 되어
        // 더 헷갈린다 (실제로 겪은 버그).
        //
        // 모서리는 원호 대신 2차 베지에로 둥글린다. 각도·회전 방향을 따질 필요가 없고,
        // iOS의 연속(continuous) 곡률에 오히려 더 가깝다.
        var path = Path()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))

        // 위쪽 변 → 오른쪽 위 모서리
        path.addLine(to: CGPoint(x: body.maxX - radius, y: body.minY))
        path.addQuadCurve(
            to: CGPoint(x: body.maxX, y: body.minY + radius),
            control: CGPoint(x: body.maxX, y: body.minY)
        )

        // 오른쪽 변 → (내 말풍선이면 꼬리) 오른쪽 아래 모서리
        if isMine, hasTail {
            path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - tailHeight))
            // 옆면에서 갈라져 끝점으로 — 바깥으로 볼록하게 부푼다.
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: body.maxY),
                control: CGPoint(x: body.maxX + 3, y: body.maxY - tailHeight * 0.45)
            )
            // 끝점에서 밑면으로 **오목하게** 감아 들어온다 — 이 갈고리가 꼬리를 꼬리로 보이게 한다.
            // 조절점이 두 끝점보다 위(y가 작다)에 있어야 위로 휘어 오목해진다.
            // 세 점의 y가 같으면 직선이 되어 꼬리가 아니라 지느러미처럼 보인다 (실제로 겪음).
            path.addQuadCurve(
                to: CGPoint(x: body.maxX - tailReturn, y: body.maxY),
                control: CGPoint(x: body.maxX - 1, y: body.maxY - tailHeight * 0.47)
            )
        } else {
            path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: body.maxX - radius, y: body.maxY),
                control: CGPoint(x: body.maxX, y: body.maxY)
            )
        }

        // 아래쪽 변(오른→왼) → (받은 말풍선이면 꼬리) 왼쪽 아래 모서리
        //
        // 진행 방향이 오른쪽 꼬리와 반대라 **두 곡선의 순서도 뒤집힌다** — 밑면에서
        // 끝점을 지나 옆면으로 올라간다. 부호만 뒤집으면 시작점으로 되돌아가 버린다.
        if !isMine, hasTail {
            path.addLine(to: CGPoint(x: body.minX + tailReturn, y: body.maxY))
            // 오목한 갈고리 (밑면 → 끝점)
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: body.maxY),
                control: CGPoint(x: body.minX + 1, y: body.maxY - tailHeight * 0.47)
            )
            // 볼록한 바깥 곡선 (끝점 → 옆면)
            path.addQuadCurve(
                to: CGPoint(x: body.minX, y: body.maxY - tailHeight),
                control: CGPoint(x: body.minX - 3, y: body.maxY - tailHeight * 0.45)
            )
        } else {
            path.addLine(to: CGPoint(x: body.minX + radius, y: body.maxY))
            path.addQuadCurve(
                to: CGPoint(x: body.minX, y: body.maxY - radius),
                control: CGPoint(x: body.minX, y: body.maxY)
            )
        }

        // 왼쪽 변 → 왼쪽 위 모서리
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: body.minX + radius, y: body.minY),
            control: CGPoint(x: body.minX, y: body.minY)
        )

        path.closeSubpath()
        return path
    }
}

/// 말풍선 하나. 색과 정렬만 정하고 배치는 호출부(`DevChatRoomView`)가 정한다.
struct DevChatBubble: View {
    let text: String
    let isMine: Bool
    let hasTail: Bool

    var body: some View {
        Text(verbatim: text)
            .foregroundStyle(isMine ? Color.white : Color.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 13)
            // 꼬리가 뻗어 나갈 자리를 본문 반대쪽에 마련한다.
            .padding(isMine ? .trailing : .leading, DevChatBubbleShape.tailWidth)
            .background {
                DevChatBubbleShape(isMine: isMine, hasTail: hasTail)
                    // 내 말풍선은 accent, 받은 말풍선은 애플 메시지처럼 중립 회색.
                    // 받은 쪽에 accent(빨강)를 쓰면 화면이 온통 빨개진다.
                    .fill(isMine ? Color.accentColor : Color(.secondarySystemFill))
            }
            .textSelection(.enabled)
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 2) {
        DevChatBubble(text: "이 말풍선은 묶음 중간이라 꼬리가 없다", isMine: true, hasTail: false)
        DevChatBubble(text: "마지막이라 꼬리가 붙는다", isMine: true, hasTail: true)

        VStack(alignment: .leading, spacing: 2) {
            DevChatBubble(text: "받은 메시지", isMine: false, hasTail: false)
            DevChatBubble(text: "받은 메시지의 마지막 줄", isMine: false, hasTail: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}
#endif
