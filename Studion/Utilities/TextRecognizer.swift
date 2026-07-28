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

    /// 관찰 결과를 화면상 위에서 아래 순서로 정렬해 줄 단위로 잇는다.
    ///
    /// Vision의 좌표계는 좌하단 원점이므로 `boundingBox.minY`가 클수록 위쪽이다.
    private static func joinLines(from observations: [VNRecognizedTextObservation]) -> String {
        observations
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
