import Foundation

/// OCR로 읽은 한 덩어리 텍스트를 **지문 / 문제 / 선택지**로 나눈다.
///
/// 순수 Swift로만 구현한다. **이 나눔은 제안일 뿐이다** — 앱이 문제를 풀거나 답을
/// 만들어내지 않는다(원칙 6). 결과는 항상 사용자가 폼에서 보고 고칠 수 있어야 하며,
/// 잘못 나뉘어도 손으로 옮기면 그만인 형태여야 한다.
enum OCRQuestionSplitter {

    struct Result: Equatable {
        /// 문제 앞에 붙는 지문·보기글. 없으면 빈 문자열.
        var passage: String
        /// 실제로 묻는 문장.
        var prompt: String
        /// 선택지. 객관식이 아니면 빈 배열.
        var choices: [String]

        var isMultipleChoice: Bool { choices.count >= 2 }

        /// 세 칸을 다시 한 덩어리 텍스트로 합친다.
        ///
        /// 목록 미리보기·백업처럼 통짜 텍스트가 필요한 곳에서 쓴다. 선택지는 원문자로 다시
        /// 붙이므로, 합친 결과를 `split`에 넣으면 원래대로 나뉜다.
        var combinedText: String {
            var parts: [String] = []
            if !passage.isEmpty { parts.append(passage) }
            if !prompt.isEmpty { parts.append(prompt) }
            if !choices.isEmpty {
                let markers = MultipleChoiceParser.choiceMarkers
                let line = choices.enumerated()
                    .map { index, choice in
                        // 표시할 원문자가 모자라면(11개 이상) 번호를 붙인다 — 실제로는 오지 않는다.
                        let marker = index < markers.count ? String(markers[index]) : "\(index + 1)."
                        return "\(marker) \(choice)"
                    }
                    .joined(separator: " ")
                parts.append(line)
            }
            return parts.joined(separator: "\n")
        }
    }

    /// 문제 줄기의 끝을 알려주는 말들. 한국 교재에서 묻는 문장은 대개 이걸로 끝난다.
    ///
    /// 이 목록으로 **문제를 이해하려는 것이 아니라**, 여러 줄 중 어느 줄이 질문인지
    /// 고르는 데만 쓴다. 못 찾으면 그냥 마지막 줄을 문제로 본다.
    private static let questionEndings = [
        "것은", "것을", "고르시오", "고르시요", "구하시오", "쓰시오", "서술하시오",
        "설명하시오", "무엇인가", "얼마인가", "옳은", "옳지", "알맞은", "적절한",
        "까닭은", "이유는", "?",
    ]

    static func split(_ text: String) -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Result(passage: "", prompt: "", choices: []) }

        let (head, choices) = extractChoices(from: trimmed)
        let (passage, prompt) = splitHead(head)
        return Result(passage: passage, prompt: prompt, choices: choices)
    }

    // MARK: - 선택지 떼어내기

    /// 선택지를 떼어내고 앞부분과 함께 돌려준다.
    ///
    /// 원문자(①②③)를 먼저 본다 — 교재 표기이므로 오탐이 거의 없다. 없으면 줄 첫머리의
    /// 번호(`1.` `2)` `(3)`)를 본다. OCR이 원문자를 숫자로 잘못 읽는 일이 잦기 때문이다.
    private static func extractChoices(from text: String) -> (head: String, choices: [String]) {
        if let parsed = MultipleChoiceParser.parse(text) {
            return (parsed.stem, parsed.choices)
        }
        if let numbered = parseNumberedChoices(text) {
            return numbered
        }
        return (text, [])
    }

    /// 줄 첫머리 번호로 된 선택지.
    ///
    /// 본문 속 "1. " 같은 표기를 선택지로 오해하지 않도록 조건을 좁게 잡는다:
    /// **줄 첫머리**에 있고, **1부터 차례대로**이며, **두 개 이상**이어야 한다.
    private static func parseNumberedChoices(_ text: String) -> (head: String, choices: [String])? {
        let lines = text.components(separatedBy: .newlines)
        var markerLines: [(lineIndex: Int, number: Int, content: String)] = []

        for (index, line) in lines.enumerated() {
            guard let (number, content) = leadingNumber(in: line) else { continue }
            // 1부터 차례대로만 받는다. 중간에 어긋나면 선택지가 아니라고 본다.
            guard number == markerLines.count + 1 else { continue }
            markerLines.append((index, number, content))
        }

        guard markerLines.count >= 2 else { return nil }

        // 선택지 사이에 끼어 있는 줄은 그 선택지의 이어지는 내용으로 붙인다.
        var choices: [String] = []
        for (offset, marker) in markerLines.enumerated() {
            let endLine = offset + 1 < markerLines.count
                ? markerLines[offset + 1].lineIndex
                : lines.count
            var parts = [marker.content]
            if marker.lineIndex + 1 < endLine {
                parts += lines[(marker.lineIndex + 1)..<endLine]
            }
            let choice = parts.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !choice.isEmpty else { return nil }
            choices.append(choice)
        }

        let head = lines[0..<markerLines[0].lineIndex]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (head, choices)
    }

    /// 줄 첫머리의 번호를 뗀다. `1.` `1)` `(1)` `1 ` 형태를 받는다.
    private static func leadingNumber(in line: String) -> (number: Int, content: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var rest = Substring(trimmed)
        let hadOpenParen = rest.first == "("
        if hadOpenParen { rest = rest.dropFirst() }

        let digits = rest.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 2, let number = Int(digits) else { return nil }
        rest = rest.dropFirst(digits.count)

        // 번호 뒤에는 구분 기호가 와야 한다. 없으면 그냥 숫자로 시작하는 문장이다.
        guard let separator = rest.first else { return nil }
        if hadOpenParen {
            guard separator == ")" else { return nil }
            rest = rest.dropFirst()
        } else {
            guard separator == "." || separator == ")" else { return nil }
            rest = rest.dropFirst()
        }

        return (number, String(rest).trimmingCharacters(in: .whitespaces))
    }

    // MARK: - 지문과 문제 가르기

    /// 선택지를 뗀 앞부분을 지문과 문제로 가른다.
    ///
    /// 묻는 문장은 보통 **맨 뒤**에 온다. 뒤에서부터 질문처럼 끝나는 줄을 찾고, 그 줄부터
    /// 끝까지를 문제로, 그 앞을 지문으로 본다. 못 찾으면 마지막 줄을 문제로 본다 — 지문만
    /// 있고 질문이 없는 텍스트는 드물기 때문이다.
    ///
    /// 질문이 여러 줄로 접혀 있으면(교재에서 흔하다) 앞줄도 함께 데려간다. 마지막 한 줄만
    /// 가져가면 "다음 중 옳은 것을 / 모두 고르면?"에서 앞 절이 지문으로 밀려 문제가 잘린다.
    private static func splitHead(_ head: String) -> (passage: String, prompt: String) {
        let lines = head
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            return ("", lines.first ?? "")
        }

        var promptIndex = lines.count - 1
        if let last = lines.lastIndex(where: looksLikeQuestion) {
            promptIndex = last
            while promptIndex > 0, looksLikeQuestion(lines[promptIndex - 1]) {
                promptIndex -= 1
            }
        }

        let passage = lines[0..<promptIndex].joined(separator: "\n")
        let prompt = lines[promptIndex...].joined(separator: " ")
        return (passage, prompt)
    }

    private static func looksLikeQuestion(_ line: String) -> Bool {
        questionEndings.contains { line.contains($0) }
    }
}
