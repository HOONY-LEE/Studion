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
                    MockExamListView()
                }
            }
            .navigationTitle("기록")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("성적 구분", selection: $tab) {
                        Text("내신").tag(Tab.school)
                        Text("모의고사").tag(Tab.mockExam)
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ReviewSessionView()
                    } label: {
                        Label("복습", systemImage: "rectangle.on.rectangle.angled")
                    }
                }
            }
        }
    }
}

#Preview {
    GradesView()
}
