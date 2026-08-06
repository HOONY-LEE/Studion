import SwiftUI

/// 객관식 선택지 한 장. 번호 배지 + 큰 글자로 "이 카드를 골랐다"가 눈에 바로 들어오게 한다.
///
/// 목록의 작은 글자 대신 카드를 쓴다 — 손가락으로 짚을 영역이 넓어지고, 글자를 키울
/// 여유가 생긴다. 오답을 빨간색으로 강조하지 않는다 — 정답만 초록으로 표시한다.
struct ChoiceCard: View {
    let index: Int
    let text: String
    let isSelected: Bool
    /// nil이면 채점 전. 채점 후에는 이 카드가 정답인지 아닌지로 스타일이 갈린다.
    let isCorrect: Bool?
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var minHeight: CGFloat = 132
    @ScaledMetric(relativeTo: .footnote) private var badgeSize: CGFloat = 28

    private var badgeColor: Color {
        if isCorrect == true { return Color("GoalAchieved") }
        return isSelected ? Color.accentColor : Color.secondary.opacity(0.35)
    }

    private var borderColor: Color {
        if isCorrect == true { return Color("GoalAchieved") }
        return isSelected ? Color.accentColor : .clear
    }

    private var backgroundTint: Color {
        isCorrect == true ? Color("GoalAchieved").opacity(0.12) : Color(.secondarySystemGroupedBackground)
    }

    var body: some View {
        Button(action: action) {
            Text(verbatim: text)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(minHeight: minHeight)
                .background(backgroundTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 2.5)
                )
                .overlay(alignment: .topLeading) {
                    Text("\(index + 1)")
                        .font(.footnote.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: badgeSize, height: badgeSize)
                        .background(badgeColor, in: Circle())
                        .offset(x: 14, y: -badgeSize / 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(index + 1)번, \(text)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            ChoiceCard(index: 0, text: "10년", isSelected: false, isCorrect: nil, action: {})
            ChoiceCard(index: 1, text: "세기", isSelected: true, isCorrect: nil, action: {})
        }
        HStack(spacing: 12) {
            ChoiceCard(index: 0, text: "10년", isSelected: true, isCorrect: true, action: {})
            ChoiceCard(index: 1, text: "세기", isSelected: false, isCorrect: false, action: {})
        }
    }
    .padding()
}
