import Foundation

/// 캘린더 일정 하나를 담는 값 타입.
///
/// EventKit의 `EKEvent`는 참조 타입이라 그대로 뷰와 로직에 흘리면 테스트가 EventKit에
/// 묶이고, 같은 반복 일정의 여러 발생을 구분하기도 어렵다. 경계에서 이 값 타입으로 바꿔
/// 담는다 — 배치·묶음 계산은 전부 이걸로 하고 `EKEvent`는 저장·삭제할 때만 다시 찾는다.
struct CalendarEvent: Identifiable, Hashable {
    /// 반복 일정은 발생마다 시작 시각이 다르므로 식별자에 시작 시각을 함께 넣는다.
    /// `eventIdentifier`만 쓰면 같은 주에 반복되는 일정이 한 칸으로 합쳐진다.
    let id: String
    let eventIdentifier: String?
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    /// 캘린더 색(빨강·파랑 등). 어느 캘린더에서 왔는지 알려주는 유일한 단서다.
    var colorHex: String?
    /// 이 앱에서 고칠 수 있는 일정인지. 구독 캘린더(공휴일 등)는 읽기 전용이다.
    var isEditable: Bool

    static func makeID(eventIdentifier: String?, start: Date) -> String {
        "\(eventIdentifier ?? "unknown")-\(start.timeIntervalSince1970)"
    }
}

/// 일정 목록을 날짜별로 가르는 계산. 순수 Swift라 EventKit 없이 테스트할 수 있다.
enum CalendarEventGrouping {

    /// 각 날짜에 걸쳐 있는 일정을 날짜별로 모은다.
    ///
    /// 하루짜리 일정만 있는 것이 아니라 **여러 날에 걸친 일정**도 있으므로, 시작일만 보고
    /// 넣으면 중간 날짜에서 사라진다. 시작~종료 사이의 모든 날에 넣는다.
    ///
    /// 자정에 끝나는 일정(예: 3일 0시 종료)은 전날까지로 본다 — 캘린더 앱들의 관례이며,
    /// 그러지 않으면 실제로는 걸치지 않는 날에 하루 더 나타난다.
    static func eventsByDay(
        _ events: [CalendarEvent], calendar: Calendar
    ) -> [Date: [CalendarEvent]] {
        var result: [Date: [CalendarEvent]] = [:]

        for event in events {
            let startDay = calendar.startOfDay(for: event.start)
            let adjustedEnd = adjustedEnd(of: event, calendar: calendar)
            let endDay = calendar.startOfDay(for: max(adjustedEnd, event.start))

            var day = startDay
            while day <= endDay {
                result[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        // 종일 일정을 먼저, 나머지는 시작 시각 순으로. 같은 시각이면 제목순으로 고정해
        // 다시 그릴 때 순서가 흔들리지 않게 한다.
        return result.mapValues { list in
            list.sorted { left, right in
                if left.isAllDay != right.isAllDay { return left.isAllDay }
                if left.start != right.start { return left.start < right.start }
                return left.title < right.title
            }
        }
    }

    /// 자정 종료를 전날 끝으로 당긴 시각. 종일 일정에는 적용하지 않는다
    /// (종일 일정의 종료는 원래 다음 날 0시로 표현된다).
    static func adjustedEnd(of event: CalendarEvent, calendar: Calendar) -> Date {
        guard !event.isAllDay else {
            return event.end > event.start
                ? event.end.addingTimeInterval(-1)
                : event.end
        }
        return event.end == calendar.startOfDay(for: event.end)
            ? event.end.addingTimeInterval(-1)
            : event.end
    }
}
