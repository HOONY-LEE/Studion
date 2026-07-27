import SwiftUI

/// 오늘 탭에 올리는 이번 학기 진척 요약 카드.
///
/// **요약이다.** 과목이 많아도 상위 몇 개만 보여주고 자세한 내용은 성적 탭에 맡긴다.
struct SemesterProgressCard: View {
    let semesterName: String
    let items: [Item]
    /// 표시하지 않고 생략한 과목 수.
    let hiddenCount: Int

    struct Item: Identifiable {
        let id: String
        let name: String
        let actual: Int
        let target: Int

        var isAchieved: Bool { actual <= target }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(semesterName)
                .font(.headline)

            ForEach(items) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.isAchieved ? "checkmark.circle.fill" : "target")
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(item.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(item.actual) / 목표 \(item.target)등급")
                        .font(.caption)
                        .monospacedDigit()
                }
                .foregroundStyle(item.isAchieved ? Color("GoalAchieved") : .secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(item.name), 현재 \(item.actual)등급, 목표 \(item.target)등급, "
                    + (item.isAchieved ? "달성" : "미달")
                )
            }

            if hiddenCount > 0 {
                Text("외 \(hiddenCount)개 과목")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SemesterProgressCard(
        semesterName: "2026학년도 1학기",
        items: [
            .init(id: "1", name: "국어", actual: 2, target: 2),
            .init(id: "2", name: "수학", actual: 3, target: 2),
        ],
        hiddenCount: 2
    )
    .padding()
}
