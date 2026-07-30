#if DEBUG
import Foundation

/// 대화 목록과 시각 구분선에 쓰는 시각 표기. 애플 메시지의 규칙을 따른다 —
/// 오늘은 시각만, 어제는 "어제", 최근 한 주는 요일, 그보다 오래되면 날짜.
///
/// 순수 로직이라 `now`와 `calendar`를 받는다. 그래야 "어제"·"한 주 전" 같은
/// 경계를 테스트할 수 있다 (실제 시계에 의존하면 테스트가 날마다 달라진다).
enum DevChatTimestamp {

    enum Style: Equatable {
        /// 오늘 — "오전 10:30"
        case time
        /// 어제
        case yesterday
        /// 최근 한 주 — "화요일"
        case weekday
        /// 그 이전 — "26. 7. 28."
        case date
    }

    static func style(for date: Date, now: Date, calendar: Calendar) -> Style {
        if calendar.isDate(date, inSameDayAs: now) { return .time }
        if calendar.isDateInYesterday(date) { return .yesterday }

        // 날짜 단위로 센다. 시:분을 그대로 빼면 "6일 23시간"이 6일로 잘려
        // 요일이 겹쳐 보이는 경계가 생긴다.
        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? 0
        return (1...6).contains(days) ? .weekday : .date
    }

    /// 대화 목록 오른쪽에 붙는 짧은 표기.
    static func listLabel(
        for date: Date, now: Date, calendar: Calendar, locale: Locale
    ) -> String {
        switch style(for: date, now: now, calendar: calendar) {
        case .time:
            return date.formatted(.dateTime.hour().minute().locale(locale))
        case .yesterday:
            return DevChatStrings.localized("어제", locale: locale)
        case .weekday:
            return date.formatted(.dateTime.weekday(.wide).locale(locale))
        case .date:
            return date.formatted(.dateTime.year(.twoDigits).month().day().locale(locale))
        }
    }

    /// 대화 안에서 말풍선 위에 놓이는 구분선 표기. 목록과 달리 **시각까지** 함께 보여준다.
    static func separatorLabel(
        for date: Date, now: Date, calendar: Calendar, locale: Locale
    ) -> String {
        let time = date.formatted(.dateTime.hour().minute().locale(locale))

        switch style(for: date, now: now, calendar: calendar) {
        case .time:
            return time
        case .yesterday:
            return "\(DevChatStrings.localized("어제", locale: locale)) \(time)"
        case .weekday:
            return "\(date.formatted(.dateTime.weekday(.wide).locale(locale))) \(time)"
        case .date:
            let day = date.formatted(.dateTime.year().month().day().locale(locale))
            return "\(day) \(time)"
        }
    }
}
#endif
