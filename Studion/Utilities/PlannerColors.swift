import SwiftUI
import UIKit

/// 캘린더·오늘 할 일 화면의 배경 색. Gradin의 `AppColors`와 같은 값이다.
///
/// 시스템 색을 그대로 쓰지 않는 이유는 다크 모드에서 카드와 배경의 대비를 Gradin과 같게
/// 맞추기 위해서다 — 시스템 grouped 색은 기기 설정에 따라 미묘하게 달라진다.
extension Color {
    /// 페이지 전체 배경 — 라이트: systemGroupedBackground / 다크: #1C1C1E
    static var plannerPageBackground: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
                : .systemGroupedBackground
        })
    }

    /// 카드/행 배경 — 라이트: 흰색 / 다크: #2C2C2E
    static var plannerCardBackground: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 44 / 255, green: 44 / 255, blue: 46 / 255, alpha: 1)
                : .white
        })
    }

    /// 달력 격자 배경 — 라이트: 흰색 / 다크: #1C1C1E
    static var plannerSurfaceBackground: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
                : .white
        })
    }
}
