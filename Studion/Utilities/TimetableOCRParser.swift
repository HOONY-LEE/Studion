import CoreGraphics
import Foundation

/// OCR이 읽은 글자 한 덩어리와 그 위치.
///
/// 좌표는 **왼쪽 위가 원점인 0~1 정규화 값**이다. Vision은 왼쪽 아래를 원점으로 주므로
/// 넣기 전에 뒤집는다 (→ `TimetableTextRecognizer`) — 시간표는 "위에서 몇 번째 줄"로
/// 읽는 것이 자연스럽고, 뒤집힌 좌표를 계산 곳곳에서 신경 쓰면 실수하기 쉽다.
struct TimetableTextBox: Equatable {
    let text: String
    let rect: CGRect

    var centerX: CGFloat { rect.midX }
    var centerY: CGFloat { rect.midY }
}

/// 시간표 **사진**을 요일 × 교시 표로 되돌린다.
///
/// 글자만 읽어서는 시간표를 복원할 수 없다 — "국어"가 화요일 3교시인지 목요일 5교시인지는
/// **글자의 위치**가 결정한다. 그래서 이 파서는 글자와 함께 위치를 받아, 사진에 찍힌
/// 요일 머리글과 교시 번호로 격자를 세운 뒤 각 글자를 그 칸에 떨어뜨린다.
///
/// **결과는 제안일 뿐이다.** OCR도 격자 추정도 틀리므로, 사용자가 표로 확인하고 고친 뒤에만
/// 저장된다 (→ `TimetableImportView`). 앱이 시간표를 확정하지 않는다.
enum TimetableOCRParser {

    /// 표의 한 칸에서 읽어낸 수업.
    struct Cell: Equatable, Identifiable {
        /// 0 = 월요일. `PlannerDateHelper.displayIndex`와 같은 기준.
        var dayIndex: Int
        var periodNumber: Int
        var title: String
        /// 이동수업 교실로 보이는 부분. 없으면 빈 문자열.
        var location: String

        var id: String { "\(dayIndex)-\(periodNumber)" }
    }

    struct Result: Equatable {
        var cells: [Cell]
        /// 사진에서 실제로 찾아낸 요일·교시. 하나도 못 찾으면 격자를 세울 수 없다.
        var foundDayCount: Int
        var foundPeriodCount: Int

        var isEmpty: Bool { cells.isEmpty }
        /// 격자를 세우지 못했는지. 화면에서 "다시 찍어달라"고 안내하는 기준이다.
        var failedToBuildGrid: Bool { foundDayCount < 2 || foundPeriodCount < 2 }
    }

    /// 요일 머리글로 인정하는 표기. 한국 시간표는 예외 없이 이 중 하나를 쓴다.
    private static let weekdayLabels: [[String]] = [
        ["월", "월요일", "MON", "Mon"],
        ["화", "화요일", "TUE", "Tue"],
        ["수", "수요일", "WED", "Wed"],
        ["목", "목요일", "THU", "Thu"],
        ["금", "금요일", "FRI", "Fri"],
        ["토", "토요일", "SAT", "Sat"],
        ["일", "일요일", "SUN", "Sun"],
    ]

    // MARK: - 파싱

    static func parse(_ boxes: [TimetableTextBox]) -> Result {
        let days = weekdayColumns(in: boxes)
        let periods = periodRows(in: boxes)

        guard days.count >= 2, periods.count >= 2 else {
            return Result(cells: [], foundDayCount: days.count, foundPeriodCount: periods.count)
        }

        // 머리글·교시 번호 자체는 수업 이름이 아니다.
        let used = Set(days.map(\.boxIndex)).union(periods.map(\.boxIndex))
        let contentBoxes = boxes.enumerated()
            .filter { !used.contains($0.offset) }
            .map(\.element)

        var grouped: [String: [TimetableTextBox]] = [:]
        for box in contentBoxes {
            guard let day = nearestDay(to: box.centerX, in: days),
                  let period = nearestPeriod(to: box.centerY, in: periods)
            else { continue }
            grouped["\(day)-\(period)", default: []].append(box)
        }

        let cells = grouped.compactMap { key, boxes -> Cell? in
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let day = Int(parts[0]),
                  let period = Int(parts[1])
            else { return nil }

            // 한 칸 안에서는 위에서 아래로 읽는다 — 보통 첫 줄이 과목, 그 아래가 교실이다.
            let lines = boxes
                .sorted { $0.centerY < $1.centerY }
                .map { $0.text.trimmed }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { return nil }

            let (title, location) = splitTitleAndLocation(lines)
            guard !title.isEmpty else { return nil }
            return Cell(dayIndex: day, periodNumber: period, title: title, location: location)
        }
        .sorted { ($0.periodNumber, $0.dayIndex) < ($1.periodNumber, $1.dayIndex) }

        return Result(cells: cells, foundDayCount: days.count, foundPeriodCount: periods.count)
    }

    // MARK: - 격자 세우기

    private struct Column {
        let dayIndex: Int
        let centerX: CGFloat
        /// 어느 것이 표 맨 위 머리글인지 고르는 데 쓴다.
        let centerY: CGFloat
        let boxIndex: Int
    }

    private struct Row {
        let periodNumber: Int
        /// 어느 것이 표 맨 왼쪽 교시 칸인지 고르는 데 쓴다.
        let centerX: CGFloat
        let centerY: CGFloat
        let boxIndex: Int
    }

    /// 요일 머리글을 찾아 세로 줄(열)을 세운다.
    ///
    /// 같은 요일 글자가 여러 번 나올 수 있으므로(표 아래 범례 등) **가장 위에 있는 것**만
    /// 쓴다 — 머리글은 표 맨 위에 있다.
    private static func weekdayColumns(in boxes: [TimetableTextBox]) -> [Column] {
        var best: [Int: Column] = [:]

        for (index, box) in boxes.enumerated() {
            guard let dayIndex = weekdayIndex(of: box.text) else { continue }
            if let existing = best[dayIndex], existing.centerY <= box.centerY { continue }
            best[dayIndex] = Column(
                dayIndex: dayIndex, centerX: box.centerX, centerY: box.centerY, boxIndex: index
            )
        }
        return fillMissingColumns(Array(best.values)).sorted { $0.centerX < $1.centerX }
    }

    /// 못 읽은 요일 열을 간격으로 메운다.
    ///
    /// **겪은 문제.** Vision은 "목" 같은 한 글자 머리글을 놓칠 때가 있다. 그러면 그 열의
    /// 수업이 통째로 사라지는데 — 하루치가 조용히 없어지는 것이라 사용자가 알아채기 어렵다.
    /// 요일은 순서가 정해져 있으므로(월화수목금) 찾은 열들의 간격에서 빠진 자리를 계산할 수 있다.
    ///
    /// 찾은 요일 **사이**만 메운다. 바깥으로 늘리면(예: 금요일을 못 읽었는데 있다고 가정)
    /// 있지도 않은 열을 만들어 엉뚱한 수업을 붙일 수 있다.
    private static func fillMissingColumns(_ found: [Column]) -> [Column] {
        guard found.count >= 2 else { return found }
        let sorted = found.sorted { $0.dayIndex < $1.dayIndex }
        guard let first = sorted.first, let last = sorted.last else { return found }

        let missing = (first.dayIndex...last.dayIndex).filter { day in
            !sorted.contains { $0.dayIndex == day }
        }
        guard !missing.isEmpty else { return found }

        // 요일 번호 → x 위치를 직선으로 맞춘다 (최소제곱).
        let n = CGFloat(sorted.count)
        let meanDay = sorted.map { CGFloat($0.dayIndex) }.reduce(0, +) / n
        let meanX = sorted.map(\.centerX).reduce(0, +) / n
        let numerator = sorted.map { (CGFloat($0.dayIndex) - meanDay) * ($0.centerX - meanX) }.reduce(0, +)
        let denominator = sorted.map { pow(CGFloat($0.dayIndex) - meanDay, 2) }.reduce(0, +)
        guard denominator > 0 else { return found }

        let slope = numerator / denominator
        let intercept = meanX - slope * meanDay
        let headerY = sorted.map(\.centerY).reduce(0, +) / n

        // boxIndex -1: 대응하는 글자 상자가 없다는 뜻. 걸러낼 것도 없다.
        let filled = missing.map { day in
            Column(
                dayIndex: day,
                centerX: slope * CGFloat(day) + intercept,
                centerY: headerY,
                boxIndex: -1
            )
        }
        return found + filled
    }

    /// 교시 번호를 찾아 가로 줄(행)을 세운다.
    ///
    /// 숫자는 수업 이름 안에도 나오므로(예: "물리학1") **왼쪽 끝 영역의 홀로 선 숫자**만
    /// 교시로 본다. 교시 칸은 표 맨 왼쪽에 있다.
    private static func periodRows(in boxes: [TimetableTextBox]) -> [Row] {
        // 요일 머리글보다 왼쪽에 있는 것이 교시 칸이다. 머리글을 못 찾았으면 왼쪽 20%로 본다.
        let days = weekdayColumnsRaw(in: boxes)
        let leftBoundary: CGFloat = days.map(\.centerX).min().map { $0 - 0.02 } ?? 0.2

        var best: [Int: Row] = [:]
        for (index, box) in boxes.enumerated() {
            guard box.centerX < leftBoundary else { continue }
            guard let number = periodNumber(of: box.text) else { continue }
            if let existing = best[number], existing.centerX <= box.centerX { continue }
            best[number] = Row(
                periodNumber: number, centerX: box.centerX, centerY: box.centerY, boxIndex: index
            )
        }
        return best.values.sorted { $0.centerY < $1.centerY }
    }

    /// `periodRows`가 왼쪽 경계를 정할 때 쓰는 요일 열. (서로 부르지 않도록 분리)
    private static func weekdayColumnsRaw(in boxes: [TimetableTextBox]) -> [Column] {
        var best: [Int: Column] = [:]
        for (index, box) in boxes.enumerated() {
            guard let dayIndex = weekdayIndex(of: box.text) else { continue }
            if let existing = best[dayIndex], existing.centerY <= box.centerY { continue }
            best[dayIndex] = Column(
                dayIndex: dayIndex, centerX: box.centerX, centerY: box.centerY, boxIndex: index
            )
        }
        return Array(best.values)
    }

    /// 가장 가까운 열. 어느 열에서도 너무 멀면 표 밖의 글자로 보고 버린다.
    private static func nearestDay(to x: CGFloat, in columns: [Column]) -> Int? {
        guard let nearest = columns.min(by: { abs($0.centerX - x) < abs($1.centerX - x) }) else {
            return nil
        }
        // 열 간격의 절반보다 멀면 그 열의 글자가 아니다.
        let tolerance = max(columnSpacing(columns) * 0.6, 0.05)
        return abs(nearest.centerX - x) <= tolerance ? nearest.dayIndex : nil
    }

    private static func nearestPeriod(to y: CGFloat, in rows: [Row]) -> Int? {
        guard let nearest = rows.min(by: { abs($0.centerY - y) < abs($1.centerY - y) }) else {
            return nil
        }
        let tolerance = max(rowSpacing(rows) * 0.6, 0.04)
        return abs(nearest.centerY - y) <= tolerance ? nearest.periodNumber : nil
    }

    private static func columnSpacing(_ columns: [Column]) -> CGFloat {
        let xs = columns.map(\.centerX).sorted()
        guard xs.count >= 2 else { return 0.15 }
        let gaps = zip(xs, xs.dropFirst()).map { $1 - $0 }
        return gaps.reduce(0, +) / CGFloat(gaps.count)
    }

    private static func rowSpacing(_ rows: [Row]) -> CGFloat {
        let ys = rows.map(\.centerY).sorted()
        guard ys.count >= 2 else { return 0.1 }
        let gaps = zip(ys, ys.dropFirst()).map { $1 - $0 }
        return gaps.reduce(0, +) / CGFloat(gaps.count)
    }

    // MARK: - 글자 해석

    static func weekdayIndex(of text: String) -> Int? {
        let cleaned = text.trimmed
        guard !cleaned.isEmpty else { return nil }
        return weekdayLabels.firstIndex { labels in
            labels.contains { $0.caseInsensitiveCompare(cleaned) == .orderedSame }
        }
    }

    /// 홀로 선 교시 번호. "3", "3교시", "3." 을 받는다.
    static func periodNumber(of text: String) -> Int? {
        var cleaned = text.trimmed
        for suffix in ["교시", ".", ")"] where cleaned.hasSuffix(suffix) {
            cleaned = String(cleaned.dropLast(suffix.count)).trimmed
        }
        guard let number = Int(cleaned), (1...12).contains(number) else { return nil }
        return number
    }

    /// 한 칸의 여러 줄을 과목명과 교실로 나눈다.
    ///
    /// 시간표에서 교실은 두 가지 모양으로 붙는다 — 과목 **아래 줄**에 오거나("수학" / "과학실"),
    /// 과목과 **같은 줄에 괄호로** 붙는다("수학(과학실)"). 둘 다 떼어낸다.
    ///
    /// 교실처럼 보이는 것이 없으면 전부 과목명으로 본다 — **글자를 잃지 않는 쪽**을 택한다.
    /// 잘못 나뉘면 사용자가 고치면 되지만, 사라진 글자는 다시 타이핑해야 한다.
    static func splitTitleAndLocation(_ lines: [String]) -> (title: String, location: String) {
        // 줄 단위로 먼저 본다. 교실이 따로 한 줄을 차지하는 흔한 모양이다.
        if lines.count > 1,
           let index = lines.indices.reversed().first(where: { looksLikeLocation(lines[$0]) }),
           index > 0 {
            let title = lines[0..<index].joined(separator: " ")
            let location = lines[index...].joined(separator: " ")
            return (title, stripBrackets(location))
        }

        // 줄로 안 나뉘면 한 줄 안에 괄호로 붙은 교실을 떼어낸다.
        let joined = lines.joined(separator: " ")
        if let (title, location) = splitInlineLocation(joined) {
            return (title, location)
        }
        return (joined, "")
    }

    /// "수학(과학실)", "국어 (3-5)" 처럼 한 줄 안에 괄호로 붙은 교실을 떼어낸다.
    ///
    /// 괄호 안이 **교실로 보일 때만** 뗀다. "확률과 통계(심화)"처럼 과목명의 일부인 괄호는
    /// 그대로 둬야 하기 때문이다.
    static func splitInlineLocation(_ line: String) -> (title: String, location: String)? {
        let trimmed = line.trimmed
        let pairs: [(Character, Character)] = [("(", ")"), ("[", "]"), ("<", ">"), ("（", "）")]

        for (open, close) in pairs {
            guard trimmed.last == close, let openIndex = trimmed.lastIndex(of: open) else { continue }
            let head = String(trimmed[trimmed.startIndex..<openIndex]).trimmed
            let inner = String(trimmed[trimmed.index(after: openIndex)..<trimmed.index(before: trimmed.endIndex)]).trimmed
            // 앞이 비면 줄 전체가 괄호 하나다 — 과목명이 없어지므로 떼지 않는다.
            guard !head.isEmpty, !inner.isEmpty, looksLikeLocation(inner) else { continue }
            return (head, inner)
        }
        return nil
    }

    /// 교실 표기로 보이는 말끝. "과학실"·"체육관"·"운동장"·"3층"·"본관 2동".
    ///
    /// 고등학교 과목명에는 이 글자로 끝나는 것이 없어서 과목과 헷갈리지 않는다
    /// (과목은 대개 -어/-학/-사/-법/-론 으로 끝난다).
    private static let locationSuffixes = ["실", "관", "장", "층", "동"]

    /// 교실 표기로 보이는지. "3-5", "과학실", "(음악실)", "301", "2층" 같은 것들.
    static func looksLikeLocation(_ line: String) -> Bool {
        let cleaned = stripBrackets(line)
        guard !cleaned.isEmpty else { return false }

        // "3-5", "2-11", "A-102" 처럼 반·호실 번호. 한쪽은 숫자여야 한다
        // ("확률-통계"처럼 숫자가 없는 것은 교실이 아니다).
        let parts = cleaned.split(separator: "-")
        if parts.count == 2, parts.allSatisfy({ !$0.isEmpty }),
           parts.contains(where: { Int($0) != nil }) {
            return true
        }

        // "301", "1203" 처럼 호실 번호. 한두 자리는 교시 번호·차시와 헷갈리므로 세 자리부터 본다.
        if cleaned.count >= 3, cleaned.allSatisfy(\.isNumber) { return true }

        return locationSuffixes.contains { cleaned.hasSuffix($0) }
    }

    private static func stripBrackets(_ text: String) -> String {
        var cleaned = text.trimmed
        let pairs: [(String, String)] = [("(", ")"), ("[", "]"), ("<", ">"), ("（", "）")]
        for (open, close) in pairs where cleaned.hasPrefix(open) && cleaned.hasSuffix(close) {
            cleaned = String(cleaned.dropFirst().dropLast()).trimmed
        }
        return cleaned
    }
}
