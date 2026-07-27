import SwiftUI

/// 오늘 탭. 시간표 요약·할 일·진척 요약은 4·5단계에서 채운다.
struct TodayView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "checklist",
                title: "오늘 할 일이 없어요",
                message: "할 일을 추가하면 여기에 표시됩니다."
            )
            .navigationTitle("오늘")
        }
    }
}

#Preview {
    TodayView()
}
