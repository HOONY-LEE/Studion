import SwiftUI

/// 성적 탭. 내신/모의고사 세그먼트는 3·4단계에서 채운다.
struct GradesView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "book.closed",
                title: "아직 성적 기록이 없어요",
                message: "이수 과목을 추가해 성적을 관리해 보세요."
            )
            .navigationTitle("성적")
        }
    }
}

#Preview {
    GradesView()
}
