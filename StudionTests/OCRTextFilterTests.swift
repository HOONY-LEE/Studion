import Foundation
import Testing
@testable import Studion

private typealias Block = OCRTextFilter.RecognizedTextBlock

@Suite("OCR 텍스트 필터")
struct OCRTextFilterTests {

    @Test("본문 사이에 있는 일반 크기 텍스트는 유지된다")
    func keepsMainContent() {
        let blocks = [
            Block(text: "3. 다음 중 옳지 않은 것은?", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.08)),
            Block(text: "① 보기 하나", boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.6, height: 0.08)),
        ]
        let result = OCRTextFilter.filterDistractions(blocks)
        #expect(result.count == 2)
    }

    @Test("상단 여백의 작은 글자(단원명 등)는 제외된다")
    func removesSmallTextNearTopEdge() {
        let blocks = [
            Block(text: "II. 수학의 활용", boundingBox: CGRect(x: 0.1, y: 0.97, width: 0.3, height: 0.02)),
            Block(text: "3. 다음 중 옳지 않은 것은?", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.08)),
            Block(text: "① 보기 하나", boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.6, height: 0.08)),
        ]
        let result = OCRTextFilter.filterDistractions(blocks)
        #expect(result.count == 2)
        #expect(!result.contains { $0.text == "II. 수학의 활용" })
    }

    @Test("하단 여백의 페이지 번호는 제외된다")
    func removesPageNumberNearBottomEdge() {
        let blocks = [
            Block(text: "3. 다음 중 옳지 않은 것은?", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.08)),
            Block(text: "① 보기 하나", boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.6, height: 0.08)),
            Block(text: "12", boundingBox: CGRect(x: 0.45, y: 0.01, width: 0.05, height: 0.02)),
        ]
        let result = OCRTextFilter.filterDistractions(blocks)
        #expect(result.count == 2)
        #expect(!result.contains { $0.text == "12" })
    }

    @Test("가장자리에 있어도 본문과 크기가 비슷하면 유지된다")
    func keepsEdgeTextWithTypicalSize() {
        let blocks = [
            Block(text: "① 보기 하나", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.6, height: 0.08)),
            Block(text: "④ 마지막 보기", boundingBox: CGRect(x: 0.1, y: 0.02, width: 0.6, height: 0.08)),
        ]
        let result = OCRTextFilter.filterDistractions(blocks)
        #expect(result.count == 2)
    }

    @Test("가장자리가 아니면 짧은 숫자여도 유지된다 (문제 번호)")
    func keepsShortNumberAwayFromEdge() {
        let blocks = [
            Block(text: "1", boundingBox: CGRect(x: 0.05, y: 0.5, width: 0.05, height: 0.08)),
            Block(text: "정답은 3번이다", boundingBox: CGRect(x: 0.15, y: 0.5, width: 0.7, height: 0.08)),
        ]
        let result = OCRTextFilter.filterDistractions(blocks)
        #expect(result.count == 2)
    }

    @Test("블록이 하나뿐이면 비교 기준이 없으므로 그대로 둔다")
    func singleBlockIsUnfiltered() {
        let blocks = [Block(text: "12", boundingBox: CGRect(x: 0.45, y: 0.01, width: 0.05, height: 0.02))]
        #expect(OCRTextFilter.filterDistractions(blocks) == blocks)
    }

    @Test("빈 입력은 빈 결과")
    func emptyInput() {
        #expect(OCRTextFilter.filterDistractions([]).isEmpty)
    }
}
