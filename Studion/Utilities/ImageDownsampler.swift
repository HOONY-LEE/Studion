import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 저장 전 이미지 용량을 억제한다.
///
/// 오답노트 이미지는 CloudKit으로 동기화되므로 사용자 iCloud 용량을 쓴다.
/// 원본 해상도를 그대로 저장하지 않고 긴 변 기준으로 줄인 뒤 JPEG로 압축한다.
///
/// `UIImage`를 다루지 않고 `Data` → `Data` 변환만 한다 (UIKit 비의존).
enum ImageDownsampler {

    /// 긴 변 최대 길이(픽셀). 문제 텍스트를 읽을 수 있으면서 용량을 줄이는 절충점.
    static let maxPixelSize = 2000

    static let jpegCompressionQuality = 0.8

    /// 리사이즈 + JPEG 압축. 변환에 실패하면 원본을 그대로 돌려준다.
    static func downsample(
        _ data: Data,
        maxPixelSize: Int = maxPixelSize,
        quality: Double = jpegCompressionQuality
    ) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return data }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return data }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return data }

        CGImageDestinationAddImage(
            destination,
            thumbnail,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else { return data }
        return output as Data
    }
}
