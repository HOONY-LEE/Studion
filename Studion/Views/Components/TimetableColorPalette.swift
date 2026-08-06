import SwiftUI

/// 시간표 칸 색.
///
/// 자산 카탈로그 대신 코드로 둔다 — 10가지 색의 명도·채도를 서로 맞춰야 하는데, 값이
/// 한자리에 모여 있어야 "이 색만 유독 튄다"를 고치기 쉽다.
///
/// 라이트/다크 모두에서 쓰려고 색을 **틴트로만** 쓴다: 배경은 옅게 깔고 글자는 시스템
/// 기본색을 유지한다. 채도가 높은 색을 배경 전체에 칠하면 다크 모드에서 글자가 묻힌다.
enum TimetableColorPalette {

    /// `TimetableColorAssigner.paletteCount`와 개수가 같아야 한다.
    static let colors: [Color] = [
        Color(hue: 0.58, saturation: 0.72, brightness: 0.80), // 파랑
        Color(hue: 0.05, saturation: 0.72, brightness: 0.88), // 주황
        Color(hue: 0.35, saturation: 0.62, brightness: 0.66), // 초록
        Color(hue: 0.78, saturation: 0.55, brightness: 0.78), // 보라
        Color(hue: 0.95, saturation: 0.58, brightness: 0.85), // 분홍
        Color(hue: 0.50, saturation: 0.68, brightness: 0.70), // 청록
        Color(hue: 0.12, saturation: 0.78, brightness: 0.82), // 노랑
        Color(hue: 0.68, saturation: 0.55, brightness: 0.78), // 남보라
        Color(hue: 0.02, saturation: 0.62, brightness: 0.80), // 빨강
        Color(hue: 0.28, saturation: 0.50, brightness: 0.62), // 올리브
    ]

    /// 색 번호에 맞는 색. 범위를 벗어나도 화면이 비지 않게 감아 돌린다.
    static func color(at index: Int) -> Color {
        guard !colors.isEmpty else { return .accentColor }
        let safe = ((index % colors.count) + colors.count) % colors.count
        return colors[safe]
    }
}
