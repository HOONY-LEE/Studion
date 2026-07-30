#if DEBUG
import Foundation

/// 대화 목록 오른쪽에 붙는 시각 표기. WorkChat iOS `ChatListView.timeText`와 같은 규칙이다 —
/// 오늘은 시각, 어제는 "어제", 그보다 오래되면 월·일.
///
/// 순수 로직이라 `now`와 `calendar`를 받는다. 그래야 "어제" 같은 경계를 테스트할 수 있다
/// (실제 시계에 의존하면 테스트 결과가 날마다 달라진다).
enum DevChatTimestamp {

    enum Style: Equatable {
        /// 오늘 — "오전 10:30"
        case time
        /// 어제
        case yesterday
        /// 그 이전 — "7월 28일"
        case date
    }

    static func style(for date: Date, now: Date, calendar: Calendar) -> Style {
        if calendar.isDate(date, inSameDayAs: now) { return .time }
        if calendar.isDateInYesterday(date) { return .yesterday }
        return .date
    }

    static func listLabel(
        for date: Date, now: Date, calendar: Calendar, locale: Locale
    ) -> String {
        switch style(for: date, now: now, calendar: calendar) {
        case .time:
            return date.formatted(.dateTime.hour().minute().locale(locale))
        case .yesterday:
            return DevChatStrings.localized("어제", locale: locale)
        case .date:
            return date.formatted(.dateTime.month().day().locale(locale))
        }
    }
}
#endif
