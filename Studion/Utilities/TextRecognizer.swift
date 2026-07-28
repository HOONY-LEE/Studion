import Foundation
import Vision

/// 온디바이스 텍스트 인식.
///
/// **이 파일이 Vision을 import하는 유일한 곳이다.** 네트워크 요청을 하지 않으며,
/// 이미지는 기기 밖으로 나가지 않는다.
///
/// 수식·기호는 1차 범위 밖이다 (텍스트 위주 문제 대상).
enum TextRecognizer {

    enum RecognitionError: Error {
        case invalidImageData
        case requestFailed(Error)
    }

    /// 인식할 언어. 한국어 우선, 영어 보조.
    static let recognitionLanguages = ["ko-KR", "en-US"]

    /// 이미지에서 텍스트를 인식한다.
    ///
    /// - Returns: 인식된 줄을 위에서 아래 순서로 이어붙인 문자열. 인식 결과가 없으면 빈 문자열.
    /// - Throws: 이미지를 읽을 수 없거나 Vision 요청이 실패한 경우
    static func recognizeText(in imageData: Data) async throws -> String {
        guard let cgImage = makeCGImage(from: imageData) else {
            throw RecognitionError.invalidImageData
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: RecognitionError.requestFailed(error))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: joinLines(from: observations))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = recognitionLanguages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: RecognitionError.requestFailed(error))
            }
        }
    }

    // MARK: - 내부

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// 관찰 결과에서 페이지 번호·머리말/꼬리말로 추정되는 블록을 걸러낸 뒤,
    /// 화면상 위에서 아래 순서로 정렬해 줄 단위로 잇는다.
    ///
    /// Vision의 좌표계는 좌하단 원점이므로 `boundingBox.minY`가 클수록 위쪽이다.
    ///
    /// - Important: 이 필터링은 휴리스틱이라 완벽하지 않다. 그래서 사용자가 결과를
    ///   확인·수정하는 단계(`WrongAnswerFormView`)를 항상 거치게 한다.
    private static func joinLines(from observations: [VNRecognizedTextObservation]) -> String {
        let blocks = observations.compactMap { observation -> OCRTextFilter.RecognizedTextBlock? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return OCRTextFilter.RecognizedTextBlock(text: text, boundingBox: observation.boundingBox)
        }

        return OCRTextFilter.filterDistractions(blocks)
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
            .map(\.text)
            .joined(separator: "\n")
    }
}
