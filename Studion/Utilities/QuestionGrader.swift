import Foundation

/// 문제 채점.
///
/// 순수 Swift로만 구현한다 — SwiftData·SwiftUI를 import하지 않으며 `@Model` 객체를 받지 않는다.
/// 명세: `docs/08-question-bank.md` §5
///
/// - Important: **앱이 정답을 추측하지 않는다.** 오타 교정·유사도 판정·부분 점수를 하지 않는다.
///   복수 정답이 필요하면 출제자가 직접 여러 개 입력한다.
enum QuestionGrader {

    enum Result: Equatable {
        case correct
        case incorrect
        /// 채점할 수 없다 — 정답이 지정되지 않았거나(객관식) 자가 채점 타입(플래시카드)이다.
        case notGraded
    }

    // MARK: - 객관식

    /// - Parameter correctIndex: `nil`이면 출제자가 정답을 지정하지 않은 것이며 채점하지 않는다.
    static func gradeMultipleChoice(selected: Int?, correctIndex: Int?) -> Result {
        guard let correctIndex else { return .notGraded }
        guard let selected else { return .incorrect }
        return selected == correctIndex ? .correct : .incorrect
    }

    // MARK: - 텍스트 답 (단답형 / 빈칸)

    /// 정규화 후 `acceptedAnswers` 중 하나와 정확히 일치하면 정답.
    static func gradeTextAnswer(_ input: String, acceptedAnswers: [String]) -> Result {
        guard !acceptedAnswers.isEmpty else { return .notGraded }

        let normalizedInput = normalize(input)
        guard !normalizedInput.isEmpty else { return .incorrect }

        let isMatch = acceptedAnswers.contains { normalize($0) == normalizedInput }
        return isMatch ? .correct : .incorrect
    }

    /// 채점용 정규화: 앞뒤 공백 제거 → 연속 공백을 하나로 → 대소문자 무시.
    ///
    /// 이 이상은 하지 않는다. "apple"과 "Apple"은 같지만 "aple"은 오답이다.
    static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    // MARK: - 빈칸 표기

    /// 빈칸으로 인식하는 표기. 출제자가 명시적으로 넣으며 앱이 위치를 추측하지 않는다.
    static let blankMarker = "____"

    /// `prompt`에 빈칸 표기가 있는지.
    static func containsBlank(_ prompt: String) -> Bool {
        prompt.contains(blankMarker)
    }

    /// 빈칸을 사용자의 답으로 채운 문장. 채점 결과 화면에서 보여주기 위한 것이다.
    static func fillingBlank(in prompt: String, with answer: String) -> String {
        guard containsBlank(prompt) else { return prompt }
        return prompt.replacingOccurrences(of: blankMarker, with: answer)
    }
}
