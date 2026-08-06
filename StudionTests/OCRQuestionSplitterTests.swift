import Foundation
import Testing
@testable import Studion

/// OCR 텍스트를 지문·문제·선택지로 나누는 규칙.
///
/// 이 나눔은 제안일 뿐이라 틀려도 사용자가 고칠 수 있지만, **내용을 잃어버리면 안 된다** —
/// 사진에서 읽은 글자가 어느 칸에도 안 들어가면 사용자가 다시 타이핑해야 한다.
@Suite("OCR 문제 나누기")
struct OCRQuestionSplitterTests {

    // MARK: 원문자 선택지

    @Test("원문자 선택지를 떼어낸다")
    func circledChoices() {
        let result = OCRQuestionSplitter.split("""
        다음 중 옳은 것은?
        ① 가 ② 나 ③ 다 ④ 라
        """)

        #expect(result.prompt == "다음 중 옳은 것은?")
        #expect(result.choices == ["가", "나", "다", "라"])
        #expect(result.isMultipleChoice)
    }

    @Test("지문이 있으면 문제와 나눈다")
    func passageSeparated() {
        let result = OCRQuestionSplitter.split("""
        철수는 사과를 3개 샀다.
        영희는 철수보다 2개 더 샀다.
        영희가 산 사과의 개수를 구하시오.
        ① 3 ② 4 ③ 5 ④ 6
        """)

        #expect(result.passage == "철수는 사과를 3개 샀다.\n영희는 철수보다 2개 더 샀다.")
        #expect(result.prompt == "영희가 산 사과의 개수를 구하시오.")
        #expect(result.choices.count == 4)
    }

    // MARK: 번호 선택지 (OCR이 원문자를 숫자로 읽는 경우)

    @Test("줄 첫머리 번호도 선택지로 읽는다")
    func numberedChoices() {
        // OCR이 ①을 1로 잘못 읽는 일이 잦다.
        let result = OCRQuestionSplitter.split("""
        다음 중 알맞은 것은?
        1. 가
        2. 나
        3. 다
        """)

        #expect(result.prompt == "다음 중 알맞은 것은?")
        #expect(result.choices == ["가", "나", "다"])
    }

    @Test("괄호 번호와 닫는 괄호 번호도 읽는다")
    func parenthesisChoices() {
        let paren = OCRQuestionSplitter.split("문제?\n(1) 가\n(2) 나")
        #expect(paren.choices == ["가", "나"])

        let closing = OCRQuestionSplitter.split("문제?\n1) 가\n2) 나")
        #expect(closing.choices == ["가", "나"])
    }

    @Test("본문 속 번호는 선택지로 오해하지 않는다")
    func numbersInBodyAreNotChoices() {
        // "3개"의 3이나 문장 중간의 숫자를 선택지로 잡으면 문제가 통째로 망가진다.
        let result = OCRQuestionSplitter.split("철수는 사과를 3개 샀다. 몇 개인가?")
        #expect(result.choices.isEmpty)
        #expect(result.prompt == "철수는 사과를 3개 샀다. 몇 개인가?")
    }

    @Test("번호가 1부터 차례대로가 아니면 선택지가 아니다")
    func outOfOrderNumbersRejected() {
        let result = OCRQuestionSplitter.split("문제?\n3. 가\n7. 나")
        #expect(result.choices.isEmpty)
    }

    @Test("번호가 하나뿐이면 선택지가 아니다")
    func singleNumberRejected() {
        let result = OCRQuestionSplitter.split("문제?\n1. 가")
        #expect(result.choices.isEmpty)
    }

    @Test("선택지가 여러 줄에 걸치면 이어 붙인다")
    func multilineChoice() {
        let result = OCRQuestionSplitter.split("""
        옳은 것은?
        1. 첫 번째 보기인데
        내용이 길어 줄이 넘어갔다
        2. 두 번째
        """)

        #expect(result.choices.count == 2)
        #expect(result.choices[0] == "첫 번째 보기인데 내용이 길어 줄이 넘어갔다")
        #expect(result.choices[1] == "두 번째")
    }

    // MARK: 지문 / 문제 가르기

    @Test("한 줄뿐이면 전부 문제로 본다")
    func singleLineIsPrompt() {
        let result = OCRQuestionSplitter.split("각 x의 크기를 구하시오.")
        #expect(result.passage.isEmpty)
        #expect(result.prompt == "각 x의 크기를 구하시오.")
    }

    @Test("질문처럼 끝나는 줄이 없으면 마지막 줄을 문제로 본다")
    func fallbackToLastLine() {
        let result = OCRQuestionSplitter.split("첫 줄\n둘째 줄\n셋째 줄")
        #expect(result.passage == "첫 줄\n둘째 줄")
        #expect(result.prompt == "셋째 줄")
    }

    @Test("질문 줄 뒤에 딸린 줄은 문제에 함께 붙인다")
    func trailingLinesJoinPrompt() {
        // 질문이 두 줄로 접힌 경우 뒷줄을 지문으로 보내면 문제가 잘린다.
        let result = OCRQuestionSplitter.split("""
        지문입니다.
        다음 중 옳은 것을
        모두 고르면?
        """)

        #expect(result.passage == "지문입니다.")
        #expect(result.prompt == "다음 중 옳은 것을 모두 고르면?")
    }

    @Test("빈 줄은 무시한다 — OCR이 줄바꿈을 여러 번 넣는다")
    func blankLinesIgnored() {
        let result = OCRQuestionSplitter.split("지문\n\n\n문제는 무엇인가?")
        #expect(result.passage == "지문")
        #expect(result.prompt == "문제는 무엇인가?")
    }

    // MARK: 빈 입력 · 내용 보존

    @Test("빈 텍스트는 빈 결과다")
    func emptyInput() {
        #expect(OCRQuestionSplitter.split("") == OCRQuestionSplitter.Result(passage: "", prompt: "", choices: []))
        #expect(OCRQuestionSplitter.split("   \n  ").prompt.isEmpty)
    }

    @Test("나눈 뒤에도 글자를 잃지 않는다")
    func nothingIsLost() {
        // 어느 칸에도 안 들어간 글자가 있으면 사용자가 다시 타이핑해야 한다.
        let source = """
        지문 첫 줄
        지문 둘째 줄
        무엇을 고르시오?
        ① 하나 ② 둘 ③ 셋
        """
        let result = OCRQuestionSplitter.split(source)
        let recombined = (result.passage + result.prompt + result.choices.joined())
            .filter { !$0.isWhitespace }
        let original = source
            .filter { !$0.isWhitespace }
            // 선택지 표시는 칸 번호로 대체되므로 원문에서 뺀다.
            .filter { !MultipleChoiceParser.choiceMarkers.contains($0) }

        #expect(recombined == original)
    }

    // MARK: 다시 합치기

    @Test("합친 뒤 다시 나누면 그대로다")
    func combineRoundTrips() {
        let original = OCRQuestionSplitter.Result(
            passage: "지문 한 줄",
            prompt: "무엇을 고르시오?",
            choices: ["하나", "둘", "셋"]
        )
        #expect(OCRQuestionSplitter.split(original.combinedText) == original)
    }

    @Test("빈 칸은 합칠 때 빈 줄을 남기지 않는다")
    func combineSkipsEmptyFields() {
        let noPassage = OCRQuestionSplitter.Result(passage: "", prompt: "문제?", choices: [])
        #expect(noPassage.combinedText == "문제?")

        let promptOnly = OCRQuestionSplitter.Result(passage: "지문", prompt: "문제?", choices: [])
        #expect(promptOnly.combinedText == "지문\n문제?")
    }

    @Test("도형 문제처럼 글자가 적어도 문제 칸에 들어간다")
    func shortTextStillFillsPrompt() {
        let result = OCRQuestionSplitter.split("x = ?")
        #expect(result.prompt == "x = ?")
        #expect(result.choices.isEmpty)
    }
}
