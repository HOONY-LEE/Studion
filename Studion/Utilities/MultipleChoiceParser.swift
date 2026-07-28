import Foundation

/// 객관식 문제 텍스트를 문제 줄기(stem)와 선택지로 나눈다.
///
/// 순수 Swift로만 구현한다. 한국 교재의 관행대로 원문자(①②③④⑤ …)를 선택지 표시로
/// 인식한다. **이 파서는 힌트일 뿐이다** — AI가 문제를 풀거나 답을 만들어내지 않는다.
/// 인식 결과는 항상 사용자가 미리보기에서 확인하고, 아니라면 서술형으로 되돌릴 수 있어야 한다.
enum MultipleChoiceParser {

    struct Result: Equatable {
        let stem: String
        let choices: [String]
    }

    /// 인식하는 원문자 표시. ①~⑩ (11개 이상 선택지는 지원하지 않는다 — 실제로 쓰이지 않는다).
    static let choiceMarkers: [Character] = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"]

    /// 최소 2개 이상의 선택지 표시가 `①②③…` 순서대로 나타나야 인식한다.
    /// - Returns: 선택지 중 하나라도 비어 있으면 `nil` (전체를 신뢰할 수 없다고 본다).
    static func parse(_ text: String) -> Result? {
        var markerPositions: [(marker: Character, index: String.Index)] = []

        var searchStart = text.startIndex
        for marker in choiceMarkers {
            guard let range = text.range(of: String(marker), range: searchStart..<text.endIndex) else { break }
            markerPositions.append((marker, range.lowerBound))
            searchStart = range.upperBound
        }

        guard markerPositions.count >= 2 else { return nil }

        let stem = String(text[text.startIndex..<markerPositions[0].index])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var choices: [String] = []
        for (offset, entry) in markerPositions.enumerated() {
            let contentStart = text.index(after: entry.index)
            let contentEnd = offset + 1 < markerPositions.count ? markerPositions[offset + 1].index : text.endIndex
            let choiceText = String(text[contentStart..<contentEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !choiceText.isEmpty else { return nil }
            choices.append(choiceText)
        }

        return Result(stem: stem, choices: choices)
    }
}
