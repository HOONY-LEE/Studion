import SwiftUI

/// 등급 또는 성취도를 표시하는 배지.
///
/// 표시 우선순위는 호출부가 정한다 — 확정 석차등급이 있으면 그것을, 없으면 추정 등급을 넘긴다.
/// 목표 달성 여부는 색상만이 아니라 아이콘으로도 드러낸다 (색상 비의존 원칙).
struct GradeBadge: View {
    enum Content: Equatable {
        case grade(Int)
        case achievement(AchievementLevel)
        case none
    }

    let content: Content
    /// 목표를 달성했는지. `nil`이면 목표가 설정되지 않은 상태다.
    var isGoalAchieved: Bool?

    private var foreground: Color {
        // 미달을 빨간색으로 강조하지 않는다. 달성은 그린, 그 외는 뉴트럴.
        isGoalAchieved == true ? Color("GoalAchieved") : .secondary
    }

    var body: some View {
        HStack(spacing: 4) {
            if isGoalAchieved == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            gradeText
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
        }
        .foregroundStyle(foreground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// 문자열 보간을 `String` 프로퍼티에 먼저 담지 않고 `Text` 호출부에서 직접 한다.
    /// 그래야 컴파일러가 `LocalizedStringKey`로 추론해 String Catalog의
    /// `"%lld등급"` 같은 포맷 키를 조회한다 — 미리 `String`으로 만들면 이 조회가 깨진다.
    @ViewBuilder
    private var gradeText: some View {
        switch content {
        case .grade(let value):
            Text("\(value)등급")
        case .achievement(let level):
            // 성취도 A~E는 언어와 무관한 기호이므로 로컬라이징 대상이 아니다.
            Text(verbatim: level.rawValue)
        case .none:
            Text(verbatim: "—")
        }
    }

    private var accessibilityLabel: Text {
        switch (content, isGoalAchieved) {
        case (.grade(let value), true):
            Text("\(value)등급, 목표 달성")
        case (.grade(let value), false):
            Text("\(value)등급, 목표 미달")
        case (.grade(let value), nil):
            Text("\(value)등급")
        case (.achievement(let level), _):
            Text(verbatim: level.rawValue)
        case (.none, _):
            Text(verbatim: "—")
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        GradeBadge(content: .grade(2), isGoalAchieved: true)
        GradeBadge(content: .grade(4), isGoalAchieved: false)
        GradeBadge(content: .grade(3))
        GradeBadge(content: .achievement(.a))
        GradeBadge(content: .none)
    }
}
