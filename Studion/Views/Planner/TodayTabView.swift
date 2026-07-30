import SwiftUI

/// 오늘 할 일 탭 — Gradin `TodayView`와 같은 구성.
///
/// 캘린더 탭과 **다른 데이터**를 다룬다: 앱이 들고 있는 할 일과 시간표다.
/// Gradin은 + 를 탭바에서 분리된 탭으로 두는데, 그 API(`Tab(role: .search)`)는 iOS 18부터라
/// 이 앱(iOS 17)에서는 화면 안 제목 줄 오른쪽에 둔다.
///
/// 시간표 관리 진입로는 여기 두지 않는다 — 학습 탭으로 옮겼다 (→ `LearnView`).
struct TodayTabView: View {
    @Environment(\.calendar) private var calendar

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            PlannerTodayView(selectedDate: $selectedDate)
                .background(Color.plannerPageBackground.ignoresSafeArea())
                // 화면 안에 큰 제목이 이미 있으므로 내비게이션 바 제목은 비운다.
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            selectedDate = PlannerDateHelper.startOfDay(selectedDate, calendar: calendar)
        }
    }
}

#Preview {
    TodayTabView()
}
