import SwiftUI

/// 할 일 한 줄. 체크는 즉시 저장되며 별도 저장 버튼이 없다.
struct PlanItemRow: View {
    let title: String
    let isDone: Bool
    let relatedSubjectName: String?
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? Color("GoalAchieved") : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)
                    if let relatedSubjectName, !relatedSubjectName.isEmpty {
                        Text(relatedSubjectName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            // 최소 터치 타깃 확보.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isDone ? "완료" : "미완료")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(alignment: .leading) {
        PlanItemRow(title: "수학 문제집 3장", isDone: false, relatedSubjectName: "수학") {}
        PlanItemRow(title: "영어 단어 암기", isDone: true, relatedSubjectName: nil) {}
    }
    .padding()
}
