import SwiftUI

/// 앞뒤로 뒤집히는 카드.
///
/// 두 면을 겹쳐 두고 Y축으로 돌린다. 핵심은 **면을 바꾸는 시점**이다 —
/// 단순히 `opacity(isFlipped ? 0 : 1)`로 하면 회전이 도는 내내 두 면이 겹쳐 비쳐
/// 글자가 뒤집힌 채 배어 나온다. 그래서 회전 각도를 애니메이션 값으로 직접 받아
/// **정확히 90°(카드가 옆으로 서서 보이지 않는 순간)** 에 면을 맞바꾼다.
struct FlipCard<Front: View, Back: View>: View {
    /// 0이면 앞면, 1이면 뒷면.
    var progress: Double

    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back

    var body: some View {
        ZStack {
            front().modifier(FlipFace(progress: progress, isBack: false))
            back().modifier(FlipFace(progress: progress, isBack: true))
        }
    }
}

/// 한 면의 회전과 보임 여부. `Animatable`이라 회전 중간값을 그대로 받는다.
private struct FlipFace: ViewModifier, Animatable {
    var progress: Double
    let isBack: Bool

    // SwiftUI가 애니메이션 중간값을 메인 액터 밖에서 넣어주므로 `nonisolated`여야 한다.
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let angle = progress * 180
        // 앞면은 0°→180°로 돌아 사라지고, 뒷면은 -180°→0°로 돌아 나타난다.
        // 뒷면을 미리 180° 돌려두지 않으면 글자가 거울처럼 뒤집혀 보인다.
        let faceAngle = isBack ? angle - 180 : angle
        let isVisible = isBack ? angle >= 90 : angle < 90

        content
            .opacity(isVisible ? 1 : 0)
            .rotation3DEffect(
                .degrees(faceAngle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.35
            )
    }
}
