import SwiftUI

/// 사진 자르기 화면.
///
/// 카메라 촬영본과 사진첩 선택본이 같은 화면을 거치게 해서, 어느 경로로 들어왔든
/// 자르는 경험이 동일하다. 카메라의 `allowsEditing`은 촬영 직후 이동/확대만
/// 지원하고 사진첩 선택본에는 아예 크롭 UI가 없어서, 공통 화면을 별도로 둔다.
///
/// 자르는 영역은 **이미지 기준 단위 사각형(0~1)** 으로 들고 다닌다. 화면 좌표로 들고 있으면
/// 화면이 회전하거나 레이아웃이 다시 잡힐 때 영역이 어긋난다 (→ `CropGeometry`).
struct PhotoCropView: View {
    let image: UIImage
    let onCrop: (Data) -> Void
    let onCancel: () -> Void

    /// 자를 영역. 이미지 왼쪽 위를 (0,0), 오른쪽 아래를 (1,1)로 본다.
    @State private var unitCrop = CropGeometry.unitFull
    /// 드래그를 시작한 시점의 영역과 방식. 드래그 도중 기준이 흔들리지 않게 붙잡아 둔다.
    @State private var dragOrigin: (rect: CGRect, mode: DragMode)?

    /// 자르기 영역의 최소 한 변 (포인트). 손가락으로 잡을 수 있는 크기여야 한다.
    private static let minimumSide: CGFloat = 60
    /// 모서리 손잡이를 잡은 것으로 볼 거리.
    private static let handleHitRadius: CGFloat = 36

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let display = CropGeometry.displayRect(imageSize: image.size, in: proxy.size)
                let crop = CropGeometry.denormalize(unitCrop, in: display)

                ZStack {
                    Color.black

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: display.width, height: display.height)
                        .position(x: display.midX, y: display.midY)

                    if display.width > 0 {
                        overlay(crop: crop)
                    }
                }
                // 이미지 바깥 여백에서 시작한 드래그도 받아야 새 영역을 그릴 수 있다.
                .contentShape(Rectangle())
                .gesture(dragGesture(display: display, crop: crop))
            }
            .ignoresSafeArea(edges: .bottom)
            .background(Color.black)
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
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { unitCrop = CropGeometry.unitFull }
                    } label: {
                        Label("전체 선택", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .tint(.white)
                    .disabled(unitCrop == CropGeometry.unitFull)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar, .bottomBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 오버레이

    private func overlay(crop: CGRect) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .reverseMask {
                    Rectangle()
                        .frame(width: crop.width, height: crop.height)
                        .position(x: crop.midX, y: crop.midY)
                }
                .allowsHitTesting(false)

            grid(in: crop)

            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: crop.width, height: crop.height)
                .position(x: crop.midX, y: crop.midY)
                .allowsHitTesting(false)

            ForEach(CropHandle.allCases) { handle in
                cornerMark(handle, in: crop)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("자를 영역")
        .accessibilityHint("끌어서 영역을 옮기고, 모서리를 끌어 크기를 조절하세요")
    }

    /// 삼분할 안내선. 어디를 자르는지 눈으로 가늠하게 해준다.
    private func grid(in crop: CGRect) -> some View {
        Path { path in
            for step in 1...2 {
                let ratio = CGFloat(step) / 3
                let x = crop.minX + crop.width * ratio
                path.move(to: CGPoint(x: x, y: crop.minY))
                path.addLine(to: CGPoint(x: x, y: crop.maxY))

                let y = crop.minY + crop.height * ratio
                path.move(to: CGPoint(x: crop.minX, y: y))
                path.addLine(to: CGPoint(x: crop.maxX, y: y))
            }
        }
        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
        .allowsHitTesting(false)
    }

    /// 모서리 표시. ㄱ자 모양이라 어느 쪽을 잡는지 분명하다.
    private func cornerMark(_ handle: CropHandle, in crop: CGRect) -> some View {
        let length: CGFloat = 22
        let thickness: CGFloat = 3
        let corner = handle.point(in: crop)
        let dx: CGFloat = handle.isLeading ? 1 : -1
        let dy: CGFloat = handle.isTop ? 1 : -1

        return ZStack {
            Rectangle()
                .frame(width: length, height: thickness)
                .offset(x: dx * (length - thickness) / 2, y: 0)
            Rectangle()
                .frame(width: thickness, height: length)
                .offset(x: 0, y: dy * (length - thickness) / 2)
        }
        .foregroundStyle(.white)
        .position(x: corner.x + dx * thickness / 2, y: corner.y + dy * thickness / 2)
        .allowsHitTesting(false)
    }

    private enum CropHandle: CaseIterable, Identifiable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
        var id: Self { self }

        var isTop: Bool { self == .topLeading || self == .topTrailing }
        var isLeading: Bool { self == .topLeading || self == .bottomLeading }

        func point(in rect: CGRect) -> CGPoint {
            CGPoint(x: isLeading ? rect.minX : rect.maxX, y: isTop ? rect.minY : rect.maxY)
        }
    }

    // MARK: - 제스처

    private enum DragMode: Equatable {
        /// 영역을 통째로 옮긴다.
        case move
        /// 잡은 모서리만 끈다.
        case resize(CropHandle)
        /// 빈 곳에서 시작했으니 새 영역을 그린다.
        case draw
    }

    /// 손잡이마다 따로 제스처를 붙이지 않고 하나로 처리한다.
    ///
    /// 겹친 제스처는 어느 쪽이 이길지 예측하기 어렵다 — 시작 지점만 보고 무엇을 할지
    /// 한 번 정한 뒤, 그 드래그가 끝날 때까지 바꾸지 않는다.
    private func dragGesture(display: CGRect, crop: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let origin = dragOrigin ?? {
                    let started = (rect: crop, mode: mode(startingAt: value.startLocation, crop: crop))
                    dragOrigin = started
                    return started
                }()

                let updated: CGRect
                switch origin.mode {
                case .move:
                    let moved = origin.rect.offsetBy(dx: value.translation.width, dy: value.translation.height)
                    updated = CropGeometry.slideInside(moved, container: display)
                case .resize(let handle):
                    updated = resized(origin.rect, handle: handle, to: value.location)
                case .draw:
                    updated = CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.location.x - value.startLocation.x),
                        height: abs(value.location.y - value.startLocation.y)
                    )
                }

                unitCrop = CropGeometry.normalize(updated, in: display, minimumSide: Self.minimumSide)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func mode(startingAt point: CGPoint, crop: CGRect) -> DragMode {
        let nearest = CropHandle.allCases.min {
            distance(point, $0.point(in: crop)) < distance(point, $1.point(in: crop))
        }
        if let nearest, distance(point, nearest.point(in: crop)) <= Self.handleHitRadius {
            return .resize(nearest)
        }
        return crop.contains(point) ? .move : .draw
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// 잡은 모서리만 옮기고 마주보는 모서리는 붙잡아 둔다.
    private func resized(_ rect: CGRect, handle: CropHandle, to point: CGPoint) -> CGRect {
        let anchorX = handle.isLeading ? rect.maxX : rect.minX
        let anchorY = handle.isTop ? rect.maxY : rect.minY
        // `standardized`가 반대로 끈 경우까지 정리하므로 음수 크기를 따로 막지 않는다.
        return CGRect(
            x: min(anchorX, point.x),
            y: min(anchorY, point.y),
            width: abs(point.x - anchorX),
            height: abs(point.y - anchorY)
        )
    }

    // MARK: - 자르기 실행

    private func crop() {
        // 방향을 픽셀에 구워 넣은 뒤에 자른다 (→ `orientedUp`).
        guard let source = image.orientedUp().cgImage else {
            onCancel()
            return
        }

        let pixelSize = CGSize(width: source.width, height: source.height)
        let rect = CropGeometry.pixelRect(unitCrop, pixelSize: pixelSize)

        // 자르기가 실패하면 원본을 그대로 넘긴다. **사진이 아예 첨부되지 않는 것보다 낫다** —
        // 자르기는 편의 기능이고, 사용자가 고른 사진을 잃는 것은 되돌릴 수 없는 손해다.
        let cropped = source.cropping(to: rect) ?? source
        guard let data = UIImage(cgImage: cropped).jpegData(compressionQuality: 0.9) else {
            onCancel()
            return
        }

        onCrop(data)
    }
}

private extension UIImage {
    /// 방향 정보를 픽셀에 실제로 반영한 이미지.
    ///
    /// 카메라 사진은 `imageOrientation`이 `.up`이 아닌 경우가 많다. 그때 `cgImage`의 픽셀은
    /// 화면에 보이는 것과 다른 방향으로 누워 있어서, 화면에서 고른 영역을 그대로 잘라내면
    /// **엉뚱한 부분이 잘리거나 범위를 벗어나 자르기가 통째로 실패한다.**
    /// 미리 회전을 구워 넣어 두 좌표계를 맞춘다.
    func orientedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
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
