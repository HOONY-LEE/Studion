import SwiftUI

/// 월간 그리드의 한 칸. 완료율을 accent color 투명도 5단계로 표시한다.
///
/// 빨강 계열을 쓰지 않는다. 데이터가 없는 날은 채움 없이 테두리만 남긴다.
struct CompletionHeatCell: View {
    let day: Int
    /// `PlannerDateHelper.heatLevel` 결과 (0...5). 0이면 데이터 없음.
    let heatLevel: Int
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let completedCount: Int
    let totalCount: Int

    /// 단계 → 투명도 매핑은 View의 책임이다 (헬퍼는 색을 모른다).
    private var fillOpacity: Double {
        switch heatLevel {
        case 1: 0.12
        case 2: 0.28
        case 3: 0.45
        case 4: 0.65
        case 5: 0.90
        default: 0
        }
    }

    private var accessibilityText: String {
        guard totalCount > 0 else {
            return String(localized: "\(day)일, 할 일 없음")
        }
        return String(localized: "\(day)일, 할 일 \(totalCount)개 중 \(completedCount)개 완료")
    }

    var body: some View {
        Text("\(day)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(fillOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .opacity(isInCurrentMonth ? 1 : 0.35)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var foregroundColor: Color {
        // 진한 배경 위에서는 대비를 위해 흰 글자를 쓴다.
        heatLevel >= 4 ? .white : .primary
    }
}

#Preview {
    HStack {
        ForEach(0...5, id: \.self) { level in
            CompletionHeatCell(
                day: level + 1,
                heatLevel: level,
                isInCurrentMonth: true,
                isSelected: level == 3,
                completedCount: level,
                totalCount: 5
            )
        }
    }
    .padding()
}
