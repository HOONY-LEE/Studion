import SwiftUI

/// 플래너 탭. 일간/주간/월간 세그먼트와 시간표는 5단계에서 채운다.
struct PlannerView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "calendar",
                title: "등록된 시간표가 없어요",
                message: "시간표를 등록하면 일정이 표시됩니다."
            )
            .navigationTitle("플래너")
        }
    }
}

#Preview {
    PlannerView()
}
