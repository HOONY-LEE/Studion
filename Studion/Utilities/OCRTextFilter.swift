import Foundation

/// OCR 인식 블록에서 페이지 번호·머리말/꼬리말로 추정되는 항목을 걸러낸다.
///
/// 순수 Swift로만 구현한다 — Vision을 import하지 않는다. `TextRecognizer`가
/// `VNRecognizedTextObservation`을 이 파일의 `RecognizedTextBlock`으로 변환해 넘긴다.
///
/// - Important: 이 필터는 **휴리스틱이며 완벽하지 않다.** 오답노트 작성 화면에서
///   사용자가 결과를 확인·수정하는 단계는 이 필터가 있어도 항상 유지한다.
enum OCRTextFilter {

    /// 정규화 좌표(0...1, 좌하단 원점)의 텍스트 블록 하나.
    struct RecognizedTextBlock: Equatable {
        let text: String
        let boundingBox: CGRect

        init(text: String, boundingBox: CGRect) {
            self.text = text
            self.boundingBox = boundingBox
        }
    }

    /// 상/하단 가장자리 판정 기준 (이미지 높이 대비 비율).
    private static let edgeMargin: Double = 0.04
    /// "이 줄은 유독 작다"고 판정하는 기준 (중앙값 대비 비율).
    private static let smallHeightRatio: Double = 0.6
    /// 페이지 번호로 볼 수 있는 최대 글자 수.
    private static let pageNumberMaxLength = 4

    /// 상하단 여백에 있으면서 유독 작거나 페이지 번호처럼 보이는 블록을 제외한다.
    ///
    /// 본문 한 줄만 있는 경우(비교 기준이 없는 경우) 아무것도 걸러내지 않는다.
    static func filterDistractions(_ blocks: [RecognizedTextBlock]) -> [RecognizedTextBlock] {
        guard blocks.count > 1 else { return blocks }

        let heights = blocks.map { $0.boundingBox.height }.sorted()
        let medianHeight = heights[heights.count / 2]

        return blocks.filter { block in
            guard isNearTopOrBottomEdge(block.boundingBox) else { return true }

            let isSmallerThanTypical = medianHeight > 0 && block.boundingBox.height < medianHeight * smallHeightRatio
            return !(isSmallerThanTypical || looksLikePageNumber(block.text))
        }
    }

    private static func isNearTopOrBottomEdge(_ box: CGRect) -> Bool {
        box.minY < edgeMargin || box.maxY > (1 - edgeMargin)
    }

    /// 숫자·점·붙임표·공백만으로 이루어진 짧은 문자열 (예: "12", "- 3 -", "p.4").
    private static func looksLikePageNumber(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= pageNumberMaxLength else { return false }
        return trimmed.allSatisfy { $0.isNumber || $0 == "-" || $0 == "." || $0 == " " }
    }
}
