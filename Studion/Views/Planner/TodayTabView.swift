import SwiftUI

/// 오늘 할 일 탭 — Gradin `TodayView`와 같은 구성.
///
/// 캘린더 탭과 **다른 데이터**를 다룬다: 앱이 들고 있는 할 일과 시간표다.
/// Gradin은 + 를 탭바에서 분리된 탭으로 두는데, 그 API(`Tab(role: .search)`)는 iOS 18부터라
/// 이 앱(iOS 17)에서는 화면 안 제목 줄 오른쪽에 둔다.
struct TodayTabView: View {
    @Environment(\.calendar) private var calendar

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var isShowingTimetable = false

    var body: some View {
        NavigationStack {
            PlannerTodayView(selectedDate: $selectedDate)
                .background(Color.plannerPageBackground.ignoresSafeArea())
                // 화면 안에 큰 제목이 이미 있으므로 내비게이션 바 제목은 비운다.
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 시간표는 이 탭이 보여주는 데이터라 관리 진입로도 여기에 둔다.
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingTimetable = true
                        } label: {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .accessibilityLabel("시간표 관리")
                    }
                }
                .sheet(isPresented: $isShowingTimetable) {
                    NavigationStack {
                        TimetableListView()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("닫기") { isShowingTimetable = false }
                                }
                            }
                    }
                }
        }
        .onAppear {
            selectedDate = PlannerDateHelper.startOfDay(selectedDate, calendar: calendar)
        }
    }
}

#Preview {
    TodayTabView()
}
