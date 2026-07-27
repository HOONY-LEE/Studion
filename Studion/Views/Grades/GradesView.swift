import SwiftUI

/// 성적 탭. 최상단 세그먼트로 내신/모의고사를 전환한다.
struct GradesView: View {
    private enum Tab: Hashable {
        case school, mockExam
    }

    @State private var tab: Tab = .school

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .school:
                    SemesterListView()
                case .mockExam:
                    // 모의고사 서브탭은 4단계에서 구현한다.
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "첫 모의고사 회차를 추가해 보세요",
                        message: "모의고사 기록은 다음 단계에서 추가됩니다."
                    )
                }
            }
            .navigationTitle("성적")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("성적 구분", selection: $tab) {
                        Text("내신").tag(Tab.school)
                        Text("모의고사").tag(Tab.mockExam)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

#Preview {
    GradesView()
}
