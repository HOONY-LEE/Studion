import Foundation

/// 학교 일과의 한 교시.
///
/// 시각은 자정 기준 **분**으로만 들고 있다. `Date`로 두면 날짜가 섞여 들어와
/// 요일마다 다른 값이 되기 쉽다 — 시간표는 "몇 시 몇 분"만 의미가 있다.
struct SchoolPeriod: Identifiable, Equatable {
    /// 1교시, 2교시 …
    let number: Int
    let startMinutes: Int
    let endMinutes: Int

    var id: Int { number }

    func contains(minutes: Int) -> Bool {
        minutes >= startMinutes && minutes < endMinutes
    }

    /// 이 교시와 시간이 조금이라도 겹치는지.
    func overlaps(start: Int, end: Int) -> Bool {
        start < endMinutes && end > startMinutes
    }
}

/// 학교 일과표. **사용자가 자기 학교에 맞게 고친다.**
///
/// 학교마다 1교시 시작 시각도 수업 길이도 다르다. 그렇다고 교시마다 시각을 하나하나
/// 적게 하면 8교시면 16번을 입력해야 한다. 대신 **네 가지 숫자**(1교시 시작 · 수업 길이 ·
/// 쉬는 시간 · 점심 길이)로 표 전체를 만든다 — 한국 고등학교는 거의 다 이 규칙으로
/// 돌아가므로, 실제로 고칠 것은 대개 "1교시 시작" 하나뿐이다.
///
/// 이 표는 **입력을 도와주는 기본값**이다. 저장되는 것은 언제나 사용자가 확인한 실제
/// 시각(`TimetableEntry.startTime/endTime`)이라, 표와 다른 시간의 수업이 있어도 문제없다.
struct SchoolPeriodSchedule: Equatable, Codable {
    /// 1교시가 시작하는 시각 (자정 기준 분).
    var firstPeriodStartMinutes: Int
    /// 수업 한 교시의 길이.
    var lessonMinutes: Int
    /// 교시 사이 쉬는 시간.
    var breakMinutes: Int
    /// 몇 교시가 끝난 뒤 점심인지. 0이면 점심시간 없음.
    var lunchAfterPeriod: Int
    /// 점심시간 길이 (쉬는 시간을 대신한다).
    var lunchMinutes: Int
    /// 표에 보여줄 교시 수.
    var periodCount: Int

    /// 일반계 고등학교에서 가장 흔한 일과. 1교시 08:40 시작, 50분 수업, 10분 쉬는 시간,
    /// 4교시 뒤 50분 점심.
    static let standard = SchoolPeriodSchedule(
        firstPeriodStartMinutes: 8 * 60 + 40,
        lessonMinutes: 50,
        breakMinutes: 10,
        lunchAfterPeriod: 4,
        lunchMinutes: 50,
        periodCount: 7
    )

    // MARK: - 허용 범위

    static let periodCountRange = 4...12
    static let lessonMinutesRange = 20...120
    static let breakMinutesRange = 0...60
    static let lunchMinutesRange = 0...120

    /// 설정값이 어떤 이유로든 범위를 벗어나도 표가 깨지지 않게 안쪽으로 당긴다.
    /// (저장된 JSON이 손상됐거나, 옛 버전이 쓴 값이 남아 있는 경우)
    var sanitized: SchoolPeriodSchedule {
        // 교시 수를 **먼저** 정리한다. 점심 위치는 교시 수 안에 있어야 하므로
        // 정리되지 않은 값에 맞추면 범위 밖으로 남는다 (테스트가 잡은 버그).
        let count = Self.periodCountRange.clamping(periodCount)
        return SchoolPeriodSchedule(
            firstPeriodStartMinutes: min(max(firstPeriodStartMinutes, 0), 24 * 60 - 1),
            lessonMinutes: Self.lessonMinutesRange.clamping(lessonMinutes),
            breakMinutes: Self.breakMinutesRange.clamping(breakMinutes),
            lunchAfterPeriod: min(max(lunchAfterPeriod, 0), count),
            lunchMinutes: Self.lunchMinutesRange.clamping(lunchMinutes),
            periodCount: count
        )
    }

    // MARK: - 교시 계산

    /// 1교시부터 `periodCount`교시까지, 앞에서부터 시각을 쌓아 만든다.
    var periods: [SchoolPeriod] {
        let safe = sanitized
        var result: [SchoolPeriod] = []
        var start = safe.firstPeriodStartMinutes

        for number in 1...safe.periodCount {
            let end = start + safe.lessonMinutes
            result.append(SchoolPeriod(number: number, startMinutes: start, endMinutes: end))
            // 점심이 낀 교시 뒤에는 쉬는 시간 대신 점심시간이 들어간다.
            start = end + (number == safe.lunchAfterPeriod ? safe.lunchMinutes : safe.breakMinutes)
        }
        return result
    }

    func period(number: Int) -> SchoolPeriod? {
        periods.first { $0.number == number }
    }

    /// 점심시간 직전 교시인지. 표에서 그 아래에 점심 구분선을 긋는 데 쓴다.
    func isBeforeLunch(_ period: SchoolPeriod) -> Bool {
        let safe = sanitized
        guard safe.lunchAfterPeriod > 0, safe.lunchMinutes > 0 else { return false }
        return period.number == safe.lunchAfterPeriod && period.number < safe.periodCount
    }

    /// 주어진 시간대와 겹치는 교시들.
    ///
    /// 시간표 칸은 교시 줄에 놓이는데 실제 일정은 교시에 딱 맞지 않을 수 있다(블록 수업, 학원).
    /// 겹치는 교시를 모두 돌려주면 그 칸을 세로로 이어 그릴 수 있다.
    func periods(overlapping start: Int, end: Int) -> [SchoolPeriod] {
        periods.filter { $0.overlaps(start: start, end: end) }
    }

    // MARK: - 저장

    /// `@AppStorage`에 담기 위한 JSON. 설정 항목이 여러 개라 키를 하나씩 두는 대신
    /// 한 덩어리로 저장한다 — 항목을 추가해도 저장 코드를 안 건드린다.
    var json: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// 저장된 JSON에서 복원한다. 비어 있거나 깨졌으면 표준 일과표로 돌아간다 —
    /// 시간표는 앱을 여는 순간 그려져야 하므로 실패를 사용자에게 떠넘기지 않는다.
    init(json: String) {
        guard !json.isEmpty,
              let decoded = try? JSONDecoder().decode(SchoolPeriodSchedule.self, from: Data(json.utf8))
        else {
            self = .standard
            return
        }
        self = decoded.sanitized
    }

    init(
        firstPeriodStartMinutes: Int,
        lessonMinutes: Int,
        breakMinutes: Int,
        lunchAfterPeriod: Int,
        lunchMinutes: Int,
        periodCount: Int
    ) {
        self.firstPeriodStartMinutes = firstPeriodStartMinutes
        self.lessonMinutes = lessonMinutes
        self.breakMinutes = breakMinutes
        self.lunchAfterPeriod = lunchAfterPeriod
        self.lunchMinutes = lunchMinutes
        self.periodCount = periodCount
    }
}

private extension ClosedRange where Bound == Int {
    func clamping(_ value: Int) -> Int {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
