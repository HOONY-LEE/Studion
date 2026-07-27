import Foundation

/// 플래너의 날짜·시간 계산을 한곳에 모은 헬퍼.
///
/// `docs/03-domain-logic.md` §4의 날짜 처리 규칙을 코드로 강제하는 지점이다.
/// 뷰가 날짜를 직접 계산하지 않고 전부 여기를 거친다.
///
/// 순수 Swift로만 구현한다 — SwiftData·SwiftUI를 import하지 않으며,
/// `Calendar`는 항상 파라미터로 주입받는다 (테스트 재현성).
enum PlannerDateHelper {

    // MARK: - 하루 단위

    /// 저장과 비교의 단일 관문. 하루 단위로 다루는 값은 전부 이걸 거친다.
    static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
        startOfDay(a, calendar: calendar) == startOfDay(b, calendar: calendar)
    }

    /// 일 단위 이동. DST가 없는 지역이라도 `+86400`으로 계산하지 않는다.
    static func addingDays(_ days: Int, to date: Date, calendar: Calendar) -> Date {
        let base = startOfDay(date, calendar: calendar)
        guard let moved = calendar.date(byAdding: .day, value: days, to: base) else { return base }
        return startOfDay(moved, calendar: calendar)
    }

    // MARK: - 요일 변환

    /// Calendar 컨벤션. **1=일요일 … 7=토요일**
    static func calendarWeekday(of date: Date, calendar: Calendar) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// 표시 순서(월요일 시작)로 변환한다. 월=0 … 일=6
    ///
    /// 모델은 Calendar 컨벤션으로 저장하고 화면은 월요일부터 보여준다.
    /// 이 변환은 **여기서만** 한다 — 뷰에 `% 7` 산술이 흩어지면 안 된다.
    static func displayIndex(forCalendarWeekday weekday: Int) -> Int {
        (weekday + 5) % 7
    }

    /// `displayIndex(forCalendarWeekday:)`의 역변환.
    static func calendarWeekday(forDisplayIndex index: Int) -> Int {
        (index + 1) % 7 + 1
    }

    // MARK: - 주 / 월 그리드

    /// 주어진 날짜가 속한 주의 월요일부터 7일. 전부 `startOfDay` 정규화된 오름차순.
    static func weekDates(containing date: Date, calendar: Calendar) -> [Date] {
        let normalized = startOfDay(date, calendar: calendar)
        let weekday = calendarWeekday(of: normalized, calendar: calendar)
        let offsetFromMonday = displayIndex(forCalendarWeekday: weekday)
        let monday = addingDays(-offsetFromMonday, to: normalized, calendar: calendar)
        return (0..<7).map { addingDays($0, to: monday, calendar: calendar) }
    }

    /// 월간 캘린더 그리드용 날짜 목록.
    /// 월요일 시작이며, 앞뒤를 이웃 달 날짜로 채워 길이가 항상 7의 배수다.
    static func monthGridDates(for date: Date, calendar: Calendar) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }

        let firstOfMonth = startOfDay(monthInterval.start, calendar: calendar)
        // dateInterval의 end는 다음 달 1일 00:00이므로 하루 되돌려 말일을 얻는다.
        let lastOfMonth = addingDays(-1, to: monthInterval.end, calendar: calendar)

        let gridStart = weekDates(containing: firstOfMonth, calendar: calendar)[0]
        let gridEnd = weekDates(containing: lastOfMonth, calendar: calendar)[6]

        var result: [Date] = []
        var cursor = gridStart
        while cursor <= gridEnd {
            result.append(cursor)
            cursor = addingDays(1, to: cursor, calendar: calendar)
        }
        return result
    }

    // MARK: - 시각 (날짜 부분 무시)

    /// 시·분 컴포넌트만 추출한다. `TimetableEntry`의 시각 비교는 전부 이걸 쓴다.
    static func minutesOfDay(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// 시작이 종료보다 앞서는지. 날짜 부분은 무시하고 시·분만 본다.
    /// 자정을 넘기는 구간은 1차 범위에서 지원하지 않으므로 `false`다.
    static func isValidTimeRange(start: Date, end: Date, calendar: Calendar) -> Bool {
        minutesOfDay(start, calendar: calendar) < minutesOfDay(end, calendar: calendar)
    }

    // MARK: - 겹침 배치

    struct TimeRange: Equatable {
        let id: UUID
        let startMinutes: Int
        let endMinutes: Int

        init(id: UUID, startMinutes: Int, endMinutes: Int) {
            self.id = id
            self.startMinutes = startMinutes
            self.endMinutes = endMinutes
        }
    }

    struct BlockLayout: Equatable {
        let id: UUID
        /// 0부터 시작하는 컬럼 인덱스.
        let column: Int
        /// 같은 겹침 그룹의 총 컬럼 수. 그룹 안의 블록은 모두 같은 너비를 갖는다.
        let columnCount: Int
    }

    /// 겹치는 일정을 나란히 배치한다. **겹침을 숨기거나 병합하지 않는다.**
    /// 경계 접촉(`a.end == b.start`)은 겹침이 아니다.
    static func layout(_ ranges: [TimeRange]) -> [BlockLayout] {
        guard !ranges.isEmpty else { return [] }

        let sorted = ranges.sorted {
            $0.startMinutes == $1.startMinutes
                ? $0.endMinutes < $1.endMinutes
                : $0.startMinutes < $1.startMinutes
        }

        // 겹치지 않는 가장 작은 인덱스 컬럼에 배치한다.
        var columnEndTimes: [Int] = []
        var assignedColumn: [UUID: Int] = [:]

        // 연결 성분(서로 이어진 겹침 그룹) 단위로 columnCount를 매기기 위해 그룹 경계를 기록한다.
        var groups: [[TimeRange]] = []
        var currentGroup: [TimeRange] = []
        var currentGroupEnd = Int.min

        for range in sorted {
            if currentGroup.isEmpty || range.startMinutes < currentGroupEnd {
                currentGroup.append(range)
                currentGroupEnd = max(currentGroupEnd, range.endMinutes)
            } else {
                groups.append(currentGroup)
                currentGroup = [range]
                currentGroupEnd = range.endMinutes
            }
        }
        if !currentGroup.isEmpty { groups.append(currentGroup) }

        var result: [BlockLayout] = []

        for group in groups {
            columnEndTimes = []
            assignedColumn = [:]

            for range in group {
                var placed = false
                for index in columnEndTimes.indices where columnEndTimes[index] <= range.startMinutes {
                    columnEndTimes[index] = range.endMinutes
                    assignedColumn[range.id] = index
                    placed = true
                    break
                }
                if !placed {
                    columnEndTimes.append(range.endMinutes)
                    assignedColumn[range.id] = columnEndTimes.count - 1
                }
            }

            let columnCount = columnEndTimes.count
            for range in group {
                result.append(
                    BlockLayout(
                        id: range.id,
                        column: assignedColumn[range.id] ?? 0,
                        columnCount: columnCount
                    )
                )
            }
        }

        return result
    }

    // MARK: - 완료율 농도

    /// 월간 히트맵의 농도 단계. 반환값은 `0...5`.
    ///
    /// 단계 → 투명도 매핑은 View의 책임이다. 이 헬퍼는 색을 모른다.
    /// - Returns: `total <= 0`이면 0 (색 없이 테두리만 표시)
    static func heatLevel(completed: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }

        let clamped = min(max(completed, 0), total)
        let ratio = Double(clamped) / Double(total)

        switch ratio {
        case 0: return 1
        case ..<0.5: return 2
        case ..<0.75: return 3
        case ..<1.0: return 4
        default: return 5
        }
    }
}
