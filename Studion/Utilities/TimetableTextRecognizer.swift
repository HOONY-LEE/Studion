import CoreGraphics
import Foundation
import ImageIO
import Vision

/// 시간표 사진에서 **글자와 그 위치**를 함께 읽는다.
///
/// `TextRecognizer`는 글자를 한 줄씩 이어 붙여 돌려주는데, 시간표는 그걸로 복원할 수 없다 —
/// "국어"가 어느 요일 어느 교시인지는 위치가 결정한다. 그래서 위치를 살려 돌려주는
/// 별도 입구를 둔다. 인식은 온디바이스이며 사진은 기기 밖으로 나가지 않는다.
enum TimetableTextRecognizer {

    enum RecognitionError: Error {
        case invalidImageData
        case requestFailed(Error)
    }

    /// 사진에서 글자 상자들을 읽는다.
    ///
    /// - Returns: 좌표를 **왼쪽 위 원점**으로 뒤집은 상자들 (→ `TimetableTextBox`).
    static func recognizeBoxes(in imageData: Data) async throws -> [TimetableTextBox] {
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
                continuation.resume(returning: observations.compactMap(makeBox))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = TextRecognizer.recognitionLanguages
            // 시간표 칸의 과목명은 사전에 없는 줄임말이 많다("확통", "생윤").
            // 언어 교정을 켜두면 엉뚱한 단어로 고쳐버린다.
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: RecognitionError.requestFailed(error))
            }
        }
    }

    /// Vision은 **왼쪽 아래**가 원점이라 y를 뒤집어야 "위에서 몇 번째 줄"이 된다.
    /// 뒤집기를 파서 곳곳에 흩어놓지 않고 이 한 곳에서 끝낸다.
    private static func makeBox(_ observation: VNRecognizedTextObservation) -> TimetableTextBox? {
        guard let text = observation.topCandidates(1).first?.string else { return nil }
        let visionRect = observation.boundingBox
        let flipped = CGRect(
            x: visionRect.minX,
            y: 1 - visionRect.maxY,
            width: visionRect.width,
            height: visionRect.height
        )
        return TimetableTextBox(text: text, rect: flipped)
    }

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
