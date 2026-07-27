import SwiftUI

/// 추정치 옆에 항상 붙는 "추정" 배지.
///
/// 색상만으로 구분하지 않고 **텍스트로** 표시한다 — 색맹 사용자도 확정값과 구분할 수 있어야 한다.
struct EstimateLabel: View {
    var body: some View {
        Text("추정")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .foregroundStyle(.secondary)
    }
}

#Preview {
    EstimateLabel()
}
