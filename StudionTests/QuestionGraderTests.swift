import Foundation
import Testing
@testable import Studion

@Suite("채점 — 객관식")
struct MultipleChoiceGradingTests {

    @Test("정답 인덱스와 같으면 정답")
    func correctSelection() {
        #expect(QuestionGrader.gradeMultipleChoice(selected: 2, correctIndex: 2) == .correct)
    }

    @Test("다르면 오답")
    func incorrectSelection() {
        #expect(QuestionGrader.gradeMultipleChoice(selected: 0, correctIndex: 2) == .incorrect)
    }

    @Test("정답이 지정되지 않았으면 채점하지 않는다")
    func noCorrectAnswerMeansNotGraded() {
        #expect(QuestionGrader.gradeMultipleChoice(selected: 1, correctIndex: nil) == .notGraded)
    }

    @Test("정답은 있는데 아무것도 고르지 않았으면 오답")
    func noSelectionIsIncorrect() {
        #expect(QuestionGrader.gradeMultipleChoice(selected: nil, correctIndex: 2) == .incorrect)
    }
}

@Suite("채점 — 텍스트 답")
struct TextAnswerGradingTests {

    @Test("정확히 일치하면 정답")
    func exactMatch() {
        #expect(QuestionGrader.gradeTextAnswer("사과", acceptedAnswers: ["사과"]) == .correct)
    }

    @Test("앞뒤 공백은 무시한다")
    func trimsWhitespace() {
        #expect(QuestionGrader.gradeTextAnswer("  사과  ", acceptedAnswers: ["사과"]) == .correct)
    }

    @Test("영어 대소문자를 무시한다")
    func caseInsensitive() {
        #expect(QuestionGrader.gradeTextAnswer("APPLE", acceptedAnswers: ["apple"]) == .correct)
        #expect(QuestionGrader.gradeTextAnswer("Apple", acceptedAnswers: ["APPLE"]) == .correct)
    }

    @Test("연속 공백을 하나로 본다")
    func collapsesInnerWhitespace() {
        #expect(
            QuestionGrader.gradeTextAnswer("hello   world", acceptedAnswers: ["hello world"]) == .correct
        )
    }

    @Test("복수 정답 중 하나만 맞아도 정답")
    func anyAcceptedAnswerMatches() {
        let answers = ["사과", "apple"]
        #expect(QuestionGrader.gradeTextAnswer("apple", acceptedAnswers: answers) == .correct)
        #expect(QuestionGrader.gradeTextAnswer("사과", acceptedAnswers: answers) == .correct)
    }

    @Test("오타는 오답이다 — 유사도 판정을 하지 않는다")
    func typoIsIncorrect() {
        #expect(QuestionGrader.gradeTextAnswer("aple", acceptedAnswers: ["apple"]) == .incorrect)
    }

    @Test("부분 일치는 오답이다")
    func partialMatchIsIncorrect() {
        #expect(QuestionGrader.gradeTextAnswer("app", acceptedAnswers: ["apple"]) == .incorrect)
    }

    @Test("빈 입력은 오답")
    func emptyInputIsIncorrect() {
        #expect(QuestionGrader.gradeTextAnswer("", acceptedAnswers: ["사과"]) == .incorrect)
        #expect(QuestionGrader.gradeTextAnswer("   ", acceptedAnswers: ["사과"]) == .incorrect)
    }

    @Test("정답이 등록되지 않았으면 채점하지 않는다")
    func noAcceptedAnswersMeansNotGraded() {
        #expect(QuestionGrader.gradeTextAnswer("아무거나", acceptedAnswers: []) == .notGraded)
    }
}

@Suite("채점 — 정규화")
struct NormalizationTests {

    @Test("정규화 규칙", arguments: [
        ("  사과  ", "사과"),
        ("APPLE", "apple"),
        ("hello   world", "hello world"),
        ("\n답\t", "답"),
        ("", ""),
    ])
    func normalizes(input: String, expected: String) {
        #expect(QuestionGrader.normalize(input) == expected)
    }
}

@Suite("빈칸 표기")
struct BlankMarkerTests {

    @Test("빈칸 표기를 인식한다")
    func detectsBlank() {
        #expect(QuestionGrader.containsBlank("The cat ____ on the mat."))
        #expect(!QuestionGrader.containsBlank("빈칸이 없는 문장"))
    }

    @Test("빈칸을 답으로 채운다")
    func fillsBlank() {
        let filled = QuestionGrader.fillingBlank(in: "The cat ____ on the mat.", with: "sat")
        #expect(filled == "The cat sat on the mat.")
    }

    @Test("빈칸이 없으면 원문을 그대로 돌려준다")
    func returnsPromptWhenNoBlank() {
        let prompt = "빈칸이 없는 문장"
        #expect(QuestionGrader.fillingBlank(in: prompt, with: "답") == prompt)
    }
}

@Suite("문제 타입")
struct QuestionTypeTests {

    @Test("플래시카드는 자동 채점 대상이 아니다")
    func flashcardIsNotAutoGradable() {
        #expect(!QuestionType.flashcard.isAutoGradable)
    }

    @Test("나머지 타입은 자동 채점한다", arguments: [
        QuestionType.multipleChoice, .fillInBlank, .shortAnswer,
    ])
    func othersAreAutoGradable(type: QuestionType) {
        #expect(type.isAutoGradable)
    }

    @Test("선택지를 쓰는 타입은 객관식뿐이다")
    func onlyMultipleChoiceUsesChoices() {
        for type in QuestionType.allCases {
            #expect(type.usesChoices == (type == .multipleChoice))
        }
    }
}
