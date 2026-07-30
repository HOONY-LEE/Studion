#if DEBUG
import Foundation
import Testing
@testable import Studion

/// 시각 표기 규칙. 실제 시계에 의존하지 않도록 `now`를 고정해 경계를 검증한다.
@Suite("개발자 메신저 시각 표기")
struct DevChatTimestampTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        // 시간대가 바뀌면 "어제"의 경계도 바뀐다. 테스트는 한 시간대로 고정한다.
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    /// 2026년 7월 30일 (목) 15:00 KST를 "지금"으로 삼는다.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 30, hour: 15))!
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test("같은 날이면 시각만 보여준다")
    func todayShowsTime() {
        #expect(DevChatTimestamp.style(for: date(7, 30, 9), now: now, calendar: calendar) == .time)
    }

    @Test("같은 날 자정 직후도 오늘이다")
    func earlyTodayIsStillToday() {
        #expect(DevChatTimestamp.style(for: date(7, 30, 0), now: now, calendar: calendar) == .time)
    }

    @Test("하루 전은 어제다")
    func yesterday() {
        #expect(DevChatTimestamp.style(for: date(7, 29, 23), now: now, calendar: calendar) == .yesterday)
    }

    @Test("이틀에서 엿새 전은 요일로 보여준다")
    func recentDaysShowWeekday() {
        for day in 24...28 {
            #expect(
                DevChatTimestamp.style(for: date(7, day), now: now, calendar: calendar) == .weekday,
                "7월 \(day)일은 요일 표기여야 합니다"
            )
        }
    }

    @Test("이레 전부터는 날짜로 보여준다")
    func olderShowsDate() {
        #expect(DevChatTimestamp.style(for: date(7, 23), now: now, calendar: calendar) == .date)
        #expect(DevChatTimestamp.style(for: date(1, 5), now: now, calendar: calendar) == .date)
    }

    @Test("시:분이 아니라 날짜 단위로 센다 — 경계에서 요일이 겹치지 않는다")
    func countsWholeDaysNotElapsedHours() {
        // 6일 23시간 전(7월 23일 16시). 흐른 시간으로 세면 6일로 잘려 요일이 되지만,
        // 날짜로 세면 7일 전이라 날짜여야 한다. 같은 요일이 두 번 나오는 걸 막는다.
        #expect(DevChatTimestamp.style(for: date(7, 23, 16), now: now, calendar: calendar) == .date)
    }

    @Test("미래 시각은 오늘이 아니면 날짜로 떨어진다 — 분류가 비지 않는다")
    func futureDatesStillClassify() {
        // 기기 시계가 어긋나 서버 시각이 미래로 보일 수 있다. 어떤 입력에도 답이 있어야 한다.
        let style = DevChatTimestamp.style(for: date(8, 5), now: now, calendar: calendar)
        #expect(style == .date)
    }

    @Test("목록 표기는 어제를 번역해 보여준다")
    func listLabelUsesTranslation() {
        let label = DevChatTimestamp.listLabel(
            for: date(7, 29), now: now, calendar: calendar, locale: Locale(identifier: "ko")
        )
        #expect(label == "어제")

        let english = DevChatTimestamp.listLabel(
            for: date(7, 29), now: now, calendar: calendar, locale: Locale(identifier: "en")
        )
        #expect(english == "Yesterday")
    }

    @Test("구분선 표기는 목록과 달리 시각을 함께 담는다")
    func separatorLabelIncludesTime() {
        let locale = Locale(identifier: "ko")
        let yesterday = DevChatTimestamp.separatorLabel(
            for: date(7, 29, 10), now: now, calendar: calendar, locale: locale
        )
        // "어제" 뒤에 시각이 붙는다. 정확한 시각 문자열은 로케일 포맷이 정하므로
        // 앞부분과 "비어 있지 않음"만 확인한다.
        #expect(yesterday.hasPrefix("어제 "))
        #expect(yesterday.count > "어제 ".count)

        // 오늘은 접두어 없이 시각만.
        let today = DevChatTimestamp.separatorLabel(
            for: date(7, 30, 9), now: now, calendar: calendar, locale: locale
        )
        #expect(!today.contains("어제"))
        #expect(!today.isEmpty)
    }
}
#endif
