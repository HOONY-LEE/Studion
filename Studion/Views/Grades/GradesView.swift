import SwiftUI

/// 기록 탭. 최상단 세그먼트로 내신/모의고사를 전환한다.
///
/// 시간표 진입로가 여기 있다 — 시간표도 "학교 생활의 기록"이고, 성적·오답노트와 같은
/// 과목 단위로 묶인다. 오답노트를 공부하는 곳은 반대로 학습 탭이다 (→ `LearnView`).
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
                    // 자식 뷰(내신/모의고사)마다 trailing 툴바 버튼의 유무·너비가 달라
                    // principal 자리가 남는 공간에 맞춰 늘었다 줄었다 하며 깨져 보였다.
                    // fixedSize로 세그먼트 자체의 고유 크기를 강제해 흔들림을 없앤다.
                    .fixedSize()
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TimetableGridView()
                    } label: {
                        Label("시간표", systemImage: "calendar.badge.clock")
                    }
                }
            }
        }
    }
}

#Preview {
    GradesView()
}
