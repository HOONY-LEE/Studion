import EventKit
import Foundation
import SwiftUI

/// 시스템 캘린더(EventKit) 접근. iCloud·Google 등 계정 동기화는 iOS가 이미 해주므로
/// 여기서는 기기의 캘린더만 읽고 쓴다 — CalDAV를 직접 다루지 않는다.
///
/// 일정은 **개발자 서버로 가지 않는다.** 기기의 캘린더에만 오간다
/// (→ `docs/00-product-principles.md` 원칙 1).
@MainActor
@Observable
final class CalendarEventStore {
    enum Access: Equatable {
        case notDetermined
        case granted
        /// 거부·제한. 안내를 보여주고 설정으로 보낸다.
        case denied
    }

    private(set) var access: Access = .notDetermined
    /// 날짜(그날 0시) → 그날에 걸쳐 있는 일정.
    private(set) var eventsByDay: [Date: [CalendarEvent]] = [:]

    private let store = EKEventStore()
    /// 이미 불러온 달(월 인덱스). 같은 달을 다시 조회하지 않는다.
    private var loadedMonths: Set<Int> = []
    private var calendar: Calendar = .current

    // MARK: - 권한

    /// 앱이 일정을 만들고 고치기도 하므로 전체 접근을 요청한다.
    func requestAccess() async {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            access = .granted
        case .denied, .restricted, .writeOnly:
            // writeOnly는 읽기가 안 되므로 달력을 채울 수 없다 — 거부와 같이 다룬다.
            access = .denied
        case .notDetermined:
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            access = granted ? .granted : .denied
        @unknown default:
            access = .denied
        }
    }

    // MARK: - 조회

    /// 그 달(앞뒤 한 달 포함)의 일정을 채운다. 이미 불러온 달은 건너뛴다.
    ///
    /// 앞뒤 달까지 함께 불러오는 이유는 월간 격자가 이전·다음 달 날짜 칸을 함께 그리기
    /// 때문이다 — 그 칸이 비어 보이면 일정이 없는 것으로 오해한다.
    func loadMonth(containing date: Date, calendar: Calendar) async {
        self.calendar = calendar
        guard access == .granted else { return }

        let index = PlannerDateHelper.monthIndex(for: date, calendar: calendar)
        let targets = [index - 1, index, index + 1].filter { !loadedMonths.contains($0) }
        guard !targets.isEmpty else { return }

        for month in targets { loadedMonths.insert(month) }

        let starts = targets.map { PlannerDateHelper.monthStart(forMonthIndex: $0, calendar: calendar) }
        guard let first = starts.min(), let last = starts.max(),
              let rangeEnd = calendar.date(byAdding: .month, value: 1, to: last)
        else { return }

        let predicate = store.predicateForEvents(withStart: first, end: rangeEnd, calendars: nil)
        let fetched = store.events(matching: predicate).map(Self.makeEvent)

        // 이미 담긴 달을 지우지 않도록 합친다. 같은 일정이 겹쳐 들어오면 id로 걸러낸다.
        let grouped = CalendarEventGrouping.eventsByDay(fetched, calendar: calendar)
        for (day, list) in grouped {
            let existing = eventsByDay[day] ?? []
            let merged = existing + list.filter { new in !existing.contains { $0.id == new.id } }
            eventsByDay[day] = merged.sorted { left, right in
                if left.isAllDay != right.isAllDay { return left.isAllDay }
                if left.start != right.start { return left.start < right.start }
                return left.title < right.title
            }
        }
    }

    func events(on day: Date) -> [CalendarEvent] {
        eventsByDay[calendar.startOfDay(for: day)] ?? []
    }

    /// 캘린더가 밖에서 바뀌었을 때(다른 앱에서 일정 추가 등) 전부 다시 읽는다.
    func reload(around date: Date, calendar: Calendar) async {
        loadedMonths.removeAll()
        eventsByDay.removeAll()
        await loadMonth(containing: date, calendar: calendar)
    }

    // MARK: - 쓰기

    /// 일정을 만들거나 고친다. `event.eventIdentifier`가 있으면 그 일정을 고친다.
    ///
    /// 반복 일정은 **이 발생만** 고친다(`.thisEvent`) — 사용자가 한 칸을 눌러 고쳤는데
    /// 나머지 반복까지 바뀌면 되돌리기 어렵다.
    func save(
        title: String, start: Date, end: Date, isAllDay: Bool,
        editing identifier: String?, calendar: Calendar
    ) throws {
        let event: EKEvent
        if let identifier, let existing = store.event(withIdentifier: identifier) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
        }

        event.title = title
        event.startDate = start
        event.endDate = max(end, start)
        event.isAllDay = isAllDay

        try store.save(event, span: .thisEvent, commit: true)
    }

    func delete(identifier: String) throws {
        guard let event = store.event(withIdentifier: identifier) else { return }
        try store.remove(event, span: .thisEvent, commit: true)
    }

    /// 새 일정을 넣을 캘린더가 있는지. 없으면(모두 읽기 전용) 추가 버튼을 숨긴다.
    var canCreateEvents: Bool {
        store.defaultCalendarForNewEvents != nil
    }

    // MARK: - 변환

    private static func makeEvent(_ event: EKEvent) -> CalendarEvent {
        let start = event.startDate ?? Date()
        return CalendarEvent(
            id: CalendarEvent.makeID(eventIdentifier: event.eventIdentifier, start: start),
            eventIdentifier: event.eventIdentifier,
            title: event.title ?? String(localized: "제목 없음"),
            start: start,
            end: event.endDate ?? start,
            isAllDay: event.isAllDay,
            colorHex: event.calendar?.cgColor.flatMap(Self.hex),
            // 구독 캘린더(공휴일 등)는 고칠 수 없다.
            isEditable: event.calendar?.allowsContentModifications ?? false
        )
    }

    private static func hex(_ color: CGColor) -> String? {
        guard let components = color.components, components.count >= 3 else { return nil }
        let values = components.prefix(3).map { Int(($0 * 255).rounded()) }
        return String(format: "%02X%02X%02X", values[0], values[1], values[2])
    }
}

extension CalendarEvent {
    /// 캘린더 색. 색을 못 읽으면 accent로 둔다 — 색이 유일한 구분 수단이 아니고
    /// 제목이 항상 함께 보이므로 폴백이 정보를 지우지 않는다.
    var color: Color {
        guard let colorHex, let value = UInt64(colorHex, radix: 16) else { return .accentColor }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
