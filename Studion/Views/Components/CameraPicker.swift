import SwiftUI
import UIKit

/// 카메라 촬영 화면.
///
/// SwiftUI에는 카메라로 **촬영**하는 네이티브 API가 없다 — `PhotosPicker`는 기존 사진 선택만 지원한다.
/// 그래서 `UIImagePickerController`를 감싼다. 이 파일이 UIKit을 쓰는 유일한 뷰다.
struct CameraPicker: UIViewControllerRepresentable {
    /// 촬영 결과를 JPEG `Data`로 돌려준다.
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let dismiss: () -> Void

        init(onCapture: @escaping (Data) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 1.0) {
                onCapture(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }

    /// 시뮬레이터에는 카메라가 없다. 호출부가 이 값으로 버튼 노출을 결정한다.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
