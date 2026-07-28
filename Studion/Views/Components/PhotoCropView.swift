import SwiftUI

/// 사진 자르기 화면.
///
/// 카메라 촬영본과 사진첩 선택본이 같은 화면을 거치게 해서, 어느 경로로 들어왔든
/// 자르는 경험이 동일하다. 카메라의 `allowsEditing`은 촬영 직후 이동/확대만
/// 지원하고 사진첩 선택본에는 아예 크롭 UI가 없어서, 공통 화면을 별도로 둔다.
struct PhotoCropView: View {
    let image: UIImage
    let onCrop: (Data) -> Void
    let onCancel: () -> Void

    @State private var cropRect: CGRect = .zero
    @State private var dragStart: CGPoint?
    @State private var imageFrame: CGRect = .zero

    /// 이미지 표시 영역 안에서 크롭 사각형이 유효한 최소 크기.
    private static let minimumCropSize: CGFloat = 40

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height)
                        .background(
                            GeometryReader { imageProxy in
                                Color.clear
                                    .onAppear { setupInitialCrop(in: imageProxy.frame(in: .named("cropArea"))) }
                            }
                        )

                    cropOverlay
                }
                .coordinateSpace(name: "cropArea")
                .gesture(dragGesture)
            }
            .navigationTitle("사진 자르기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { onCancel() }
                        .tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { crop() }
                        .tint(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 크롭 오버레이

    private var cropOverlay: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.5)
                    .reverseMask {
                        Rectangle()
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                    }

                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)

                ForEach(CropHandle.allCases) { handle in
                    handleView(handle)
                }
            }
            .onAppear { imageFrame = proxy.frame(in: .named("cropArea")) }
        }
    }

    private enum CropHandle: CaseIterable, Identifiable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
        var id: Self { self }
    }

    private func handleView(_ handle: CropHandle) -> some View {
        let position: CGPoint
        switch handle {
        case .topLeading: position = CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topTrailing: position = CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeading: position = CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomTrailing: position = CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }

        return Circle()
            .fill(Color.white)
            .frame(width: 24, height: 24)
            .shadow(radius: 2)
            .position(position)
            .gesture(
                DragGesture(coordinateSpace: .named("cropArea"))
                    .onChanged { value in resizeCrop(handle: handle, to: value.location) }
            )
            .accessibilityLabel("자르기 크기 조절 손잡이")
    }

    // MARK: - 제스처

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .named("cropArea"))
            .onChanged { value in
                if dragStart == nil {
                    dragStart = value.startLocation
                }
                guard let start = dragStart else { return }
                cropRect = CGRect(
                    x: min(start.x, value.location.x),
                    y: min(start.y, value.location.y),
                    width: abs(value.location.x - start.x),
                    height: abs(value.location.y - start.y)
                ).intersection(imageFrame)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func resizeCrop(handle: CropHandle, to point: CGPoint) {
        var rect = cropRect
        switch handle {
        case .topLeading:
            rect = CGRect(x: point.x, y: point.y, width: rect.maxX - point.x, height: rect.maxY - point.y)
        case .topTrailing:
            rect = CGRect(x: rect.minX, y: point.y, width: point.x - rect.minX, height: rect.maxY - point.y)
        case .bottomLeading:
            rect = CGRect(x: point.x, y: rect.minY, width: rect.maxX - point.x, height: point.y - rect.minY)
        case .bottomTrailing:
            rect = CGRect(x: rect.minX, y: rect.minY, width: point.x - rect.minX, height: point.y - rect.minY)
        }

        guard rect.width >= Self.minimumCropSize, rect.height >= Self.minimumCropSize else { return }
        cropRect = rect.intersection(imageFrame)
    }

    private func setupInitialCrop(in frame: CGRect) {
        guard cropRect == .zero, frame.width > 0 else { return }
        imageFrame = frame
        // 처음에는 이미지 전체에서 살짝 안쪽으로 들어온 영역을 기본값으로 둔다.
        let inset = min(frame.width, frame.height) * 0.08
        cropRect = frame.insetBy(dx: inset, dy: inset)
    }

    // MARK: - 자르기 실행

    private func crop() {
        guard imageFrame.width > 0, imageFrame.height > 0 else {
            onCancel()
            return
        }

        // 화면 표시 좌표계(cropRect, imageFrame) → 원본 이미지 픽셀 좌표계로 변환.
        let scaleX = image.size.width / imageFrame.width
        let scaleY = image.size.height / imageFrame.height

        let pixelRect = CGRect(
            x: (cropRect.minX - imageFrame.minX) * scaleX,
            y: (cropRect.minY - imageFrame.minY) * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        guard let cgImage = image.cgImage?.cropping(to: pixelRect),
              let data = UIImage(cgImage: cgImage, scale: 1, orientation: image.imageOrientation)
                .jpegData(compressionQuality: 1.0)
        else {
            onCancel()
            return
        }

        onCrop(data)
    }
}

private extension View {
    /// 지정한 영역만 투명하게 뚫어 나머지를 어둡게 덮는다 (크롭 오버레이용).
    @ViewBuilder
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}
