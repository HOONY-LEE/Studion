import Foundation

/// 오답노트 복습 스케줄 (단순 Leitner box).
///
/// 순수 Swift로만 구현한다 — SwiftData·SwiftUI를 import하지 않으며 `Calendar`를 주입받는다.
/// 명세와 테스트 벡터: `docs/03-domain-logic.md` §3
///
/// 복잡한 SM-2 알고리즘을 쓰지 않는다. 학생이 이해할 수 있는 단순한 규칙이 목적이다.
enum ReviewScheduler {

    /// 박스별 복습 간격(일). box 0→1일, 1→3일, 2→7일, 3→14일, 4→30일
    static let intervals: [Int] = [1, 3, 7, 14, 30]

    static let maxBoxIndex = intervals.count - 1

    enum ReviewOutcome {
        case correct, incorrect
    }

    struct ReviewSchedule: Equatable {
        let boxIndex: Int
        let nextReviewDate: Date
    }

    /// 복습 결과를 반영해 다음 박스와 복습일을 계산한다.
    ///
    /// - 맞음: 박스를 한 칸 올린다 (상한 유지)
    /// - 틀림: 박스를 0으로 되돌린다
    ///
    /// - Parameter currentBox: 범위 밖 값이 들어와도 `0...maxBoxIndex`로 클램프한다.
    static func nextSchedule(
        currentBox: Int,
        outcome: ReviewOutcome,
        reviewedAt: Date,
        calendar: Calendar
    ) -> ReviewSchedule {
        let clamped = min(max(currentBox, 0), maxBoxIndex)

        let newBox: Int
        switch outcome {
        case .correct: newBox = min(clamped + 1, maxBoxIndex)
        case .incorrect: newBox = 0
        }

        return ReviewSchedule(
            boxIndex: newBox,
            nextReviewDate: date(daysFromNow: intervals[newBox], base: reviewedAt, calendar: calendar)
        )
    }

    /// 신규 카드의 최초 스케줄.
    ///
    /// 방금 문제를 본 상태이므로 **생성 당일에는 복습 대상에 넣지 않는다.**
    static func initialSchedule(createdAt: Date, calendar: Calendar) -> ReviewSchedule {
        ReviewSchedule(
            boxIndex: 0,
            nextReviewDate: date(daysFromNow: intervals[0], base: createdAt, calendar: calendar)
        )
    }

    /// 오늘 복습할 카드인지.
    ///
    /// 지난 카드도 계속 due로 남는다 — 밀린 복습이 조용히 사라지지 않게 한다.
    static func isDue(nextReviewDate: Date, on date: Date, calendar: Calendar) -> Bool {
        let due = calendar.startOfDay(for: nextReviewDate)
        let today = calendar.startOfDay(for: date)
        return due <= today
    }

    // MARK: - 내부

    /// `+86400` 산술을 쓰지 않는다. 반드시 `calendar.date(byAdding:)`을 거친다.
    private static func date(daysFromNow days: Int, base: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: base)
        guard let moved = calendar.date(byAdding: .day, value: days, to: start) else { return start }
        return calendar.startOfDay(for: moved)
    }
}
