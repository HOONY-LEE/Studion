import SwiftUI

/// 데이터가 없는 화면에 공통으로 쓰는 빈 상태 뷰.
/// 아이콘 → 제목 → 설명 → (선택) 기본 동작 버튼 1개 구조를 갖는다.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("액션 없음") {
    EmptyStateView(
        systemImage: "checklist",
        title: "오늘 할 일이 없어요",
        message: "할 일을 추가하면 여기에 표시됩니다."
    )
}

#Preview("액션 있음") {
    EmptyStateView(
        systemImage: "book.closed",
        title: "아직 성적 기록이 없어요",
        message: "이수 과목을 추가해 성적을 관리해 보세요.",
        actionTitle: "과목 추가",
        action: {}
    )
}
