import SwiftUI

/// Gradin의 유리 재질(Liquid Glass) 표현을 이 앱의 배포 타깃에서도 쓸 수 있게 감싼 것.
///
/// **Gradin은 iOS 26을 요구하지만 이 앱은 iOS 17부터 지원한다.** `glassEffect`와
/// `.buttonStyle(.glass)`는 iOS 26 API라 그대로 쓰면 컴파일되지 않는다. 그래서
/// 가능한 기기에서는 진짜 유리 재질을 쓰고, 그 아래에서는 반투명 재질 + 얇은 테두리로
/// 같은 자리를 채운다 — iOS 26 기기에서는 Gradin과 동일하게 보이고, 그 아래에서도
/// 형태와 배치는 같다.
extension View {
    /// 알약(캡슐) 모양 유리 배경.
    @ViewBuilder
    func glassPill() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    /// 둥근 사각형 유리 배경.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    /// 강조색으로 물든 원형 유리 배경 (확인 버튼 등).
    @ViewBuilder
    func glassCircle(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: .circle)
        } else {
            self.background(tint, in: Circle())
        }
    }
}

/// 상단 바 알약 버튼. Gradin의 `.buttonStyle(.glass)` 자리.
struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .glassPill()
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
