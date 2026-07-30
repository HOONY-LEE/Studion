import SwiftUI

/// 달력 요일 머리글. 캘린더 탭의 월간·주간이 함께 쓴다.
///
/// 주말 색은 **요일 번호로** 판단한다 — 첫 요일 설정(일요일 시작 / 월요일 시작)이 바뀌어도
/// 토·일에 정확히 붙는다. 열 순서로 판단하면 설정이 바뀔 때 엉뚱한 요일이 물든다.
struct PlannerWeekdayHeader: View {
    @Environment(\.calendar) private var calendar

    var body: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekday = calendar.firstWeekday

        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let weekday = (firstWeekday - 1 + index) % 7 + 1
                Text(verbatim: symbols[weekday - 1])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PlannerWeekdayHeader.color(weekday: weekday))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    /// 일요일 빨강 / 토요일 파랑. 이 빨강은 브랜드 accent가 아니라 달력의 관습이다.
    static func color(weekday: Int) -> Color {
        weekday == 1 ? .red : weekday == 7 ? .blue : .secondary
    }
}

#Preview {
    PlannerWeekdayHeader()
}
