import Foundation
import Testing
@testable import Studion

@Suite("객관식 파서")
struct MultipleChoiceParserTests {

    @Test("4지선다 문제를 줄기와 선택지로 나눈다")
    func parsesFourChoices() throws {
        let text = """
        3. 다음 중 옳지 않은 것은?
        ① 함수의 극한값은 항상 존재한다
        ② 연속함수는 미분가능하지 않을 수 있다
        ③ The answer is not always obvious
        ④ 정답은 3번이다
        """
        let result = try #require(MultipleChoiceParser.parse(text))
        #expect(result.stem == "3. 다음 중 옳지 않은 것은?")
        #expect(result.choices == [
            "함수의 극한값은 항상 존재한다",
            "연속함수는 미분가능하지 않을 수 있다",
            "The answer is not always obvious",
            "정답은 3번이다",
        ])
    }

    @Test("5지선다도 인식한다")
    func parsesFiveChoices() throws {
        let text = "문제\n①A\n②B\n③C\n④D\n⑤E"
        let result = try #require(MultipleChoiceParser.parse(text))
        #expect(result.choices.count == 5)
        #expect(result.choices == ["A", "B", "C", "D", "E"])
    }

    @Test("원문자가 없으면 nil")
    func returnsNilWithoutMarkers() {
        #expect(MultipleChoiceParser.parse("그냥 서술형 문제입니다.") == nil)
    }

    @Test("원문자가 하나뿐이면 nil (선택지로 보기엔 부족하다)")
    func returnsNilWithSingleMarker() {
        #expect(MultipleChoiceParser.parse("문제\n① 유일한 보기") == nil)
    }

    @Test("선택지 중 하나라도 비어 있으면 전체를 nil로 처리한다")
    func returnsNilWithEmptyChoice() {
        #expect(MultipleChoiceParser.parse("문제\n①\n② 보기") == nil)
    }

    @Test("빈 문자열은 nil")
    func returnsNilForEmptyString() {
        #expect(MultipleChoiceParser.parse("") == nil)
    }

    @Test("줄기가 없어도(사진을 선택지부터 잘랐어도) 인식한다")
    func allowsEmptyStem() throws {
        let result = try #require(MultipleChoiceParser.parse("① 첫 보기\n② 둘째 보기"))
        #expect(result.stem == "")
        #expect(result.choices.count == 2)
    }
}
