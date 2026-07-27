import SwiftUI
import SwiftData

/// 플래너 탭. 일간/주간/월간을 전환하며, 선택한 날짜는 세 뷰가 공유한다.
struct PlannerView: View {
    private enum Mode: Hashable {
        case daily, weekly, monthly
    }

    @Environment(\.calendar) private var calendar

    @State private var mode: Mode = .daily
    @State private var selectedDate = Date()

    @Query private var entries: [TimetableEntry]

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .daily:
                    DailyPlannerView(selectedDate: $selectedDate)
                case .weekly:
                    WeeklyPlannerView(selectedDate: $selectedDate)
                case .monthly:
                    MonthlyPlannerView(selectedDate: $selectedDate)
                }
            }
            .navigationTitle("플래너")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("보기", selection: $mode) {
                        Text("일간").tag(Mode.daily)
                        Text("주간").tag(Mode.weekly)
                        Text("월간").tag(Mode.monthly)
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        TimetableListView()
                    } label: {
                        Label("시간표 관리", systemImage: "calendar")
                    }
                }
            }
            .onAppear {
                selectedDate = PlannerDateHelper.startOfDay(selectedDate, calendar: calendar)
            }
        }
    }
}

#Preview {
    PlannerView()
}
