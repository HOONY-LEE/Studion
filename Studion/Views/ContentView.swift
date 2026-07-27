import SwiftUI

/// 2단계에서 4탭 구조로 교체될 임시 루트 뷰.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Studion")
                .font(.largeTitle.bold())
            Text("프로젝트 스캐폴딩 완료 — 다음 단계에서 탭 구조를 추가합니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    ContentView()
}
