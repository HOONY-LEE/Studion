import SwiftUI
import Photos
import UIKit

/// 첨부 시트 — 상단에 최근 사진 가로 스트립(다중 선택), 아래에 사진(앨범)/파일 메뉴.
/// WorkChat iOS `AttachmentSheet`와 같은 구성이다.
///
/// - Important: 이 시트 안에서 `.photosPicker`/`.fileImporter`/`.fullScreenCover` 같은
///   **중첩 프레젠테이션을 띄우지 않는다.** 시트를 닫은 뒤 부모가 `onDismiss`에서 띄운다
///   (중첩하면 시트가 닫힌 뒤 다시 나타나는 iOS 버그를 밟는다 — WorkChat도 같은 이유로 분리했다).
struct DevChatAttachmentSheet: View {
    /// 최근 사진 스트립에서 고른 이미지들(원본 바이트).
    var onSendPhotos: ([Data]) -> Void
    var onChooseAlbum: () -> Void
    var onChooseFile: () -> Void
    var onChooseCamera: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var library = DevChatRecentPhotos()
    /// 고른 순서를 지키기 위해 Set이 아니라 배열로 담는다.
    @State private var selected: [String] = []
    @State private var preparing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            photoStrip
            Divider().padding(.top, 12)
            menuRows
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .task { await library.load() }
    }

    private var header: some View {
        HStack {
            Text("최근 사진")
                .font(.title3.weight(.bold))
            Spacer()
            Button {
                Task { await sendSelected() }
            } label: {
                Text(selected.isEmpty ? "전송" : "전송 \(selected.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(selected.isEmpty
                        ? AnyShapeStyle(Color(.secondarySystemFill))
                        : AnyShapeStyle(Color.accentColor)))
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty || preparing)
        }
        .padding(.horizontal, 20)
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                cameraTile
                ForEach(library.assets, id: \.localIdentifier) { asset in
                    DevChatPhotoThumb(
                        asset: asset,
                        order: selected.firstIndex(of: asset.localIdentifier).map { $0 + 1 }
                    ) { toggle(asset) }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 150)
        .padding(.top, 16)
        .overlay {
            if library.assets.isEmpty, library.didLoad {
                Text("사진 접근을 허용하면 최근 사진이 보입니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private var cameraTile: some View {
        Button {
            onChooseCamera()
            dismiss()
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray4))
                .frame(width: 112, height: 150)
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("카메라로 촬영")
    }

    private var menuRows: some View {
        VStack(spacing: 0) {
            menuRow(icon: "photo.fill.on.rectangle.fill",
                    tint: Color(red: 0.18, green: 0.78, blue: 0.35),
                    title: "사진") { onChooseAlbum(); dismiss() }
            menuRow(icon: "folder.fill",
                    tint: Color(red: 0.0, green: 0.55, blue: 0.95),
                    title: "파일") { onChooseFile(); dismiss() }
        }
    }

    private func menuRow(
        icon: String, tint: Color, title: LocalizedStringKey, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint))
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ asset: PHAsset) {
        if let index = selected.firstIndex(of: asset.localIdentifier) {
            selected.remove(at: index)
        } else {
            selected.append(asset.localIdentifier)
        }
    }

    private func sendSelected() async {
        preparing = true
        defer { preparing = false }

        var datas: [Data] = []
        for id in selected {
            guard let asset = library.assets.first(where: { $0.localIdentifier == id }),
                  let data = await DevChatRecentPhotos.fullImageData(asset) else { continue }
            datas.append(data)
        }
        guard !datas.isEmpty else { return }
        onSendPhotos(datas)
        dismiss()
    }
}

/// 최근 사진 40장. 권한이 없으면 빈 목록으로 남고 시트는 앨범/파일 메뉴만 쓸 수 있다.
@MainActor
@Observable
final class DevChatRecentPhotos {
    private(set) var assets: [PHAsset] = []
    private(set) var didLoad = false

    func load() async {
        guard !didLoad else { return }
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { continuation.resume(returning: $0) }
        }
        didLoad = true
        guard status == .authorized || status == .limited else { return }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 40
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var collected: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in collected.append(asset) }
        assets = collected
    }

    /// 전송용 원본 이미지 데이터.
    static func fullImageData(_ asset: PHAsset) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}

private struct DevChatPhotoThumb: View {
    let asset: PHAsset
    /// 선택 순번(1부터). 미선택이면 nil.
    let order: Int?
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: 112, height: 150)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            badge.padding(8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(order != nil ? Color.accentColor : .clear, lineWidth: 3))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear(perform: requestThumbnail)
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(order != nil ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.black.opacity(0.25)))
                .frame(width: 24, height: 24)
            Circle().stroke(.white, lineWidth: 1.5).frame(width: 24, height: 24)
            if let order {
                Text("\(order)").font(.caption2.bold()).foregroundStyle(.white)
            }
        }
    }

    private func requestThumbnail() {
        guard image == nil else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 240, height: 320),
            contentMode: .aspectFill, options: options
        ) { result, _ in
            if let result { self.image = result }
        }
    }
}

/// 카메라 — 부모에서 `fullScreenCover`로 띄운다.
struct DevChatCameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: DevChatCameraPicker
        init(_ parent: DevChatCameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
