import CoreGraphics

/// 사진 자르기 화면의 좌표 계산.
///
/// 화면 좌표(포인트)와 원본 픽셀 좌표를 오가는 계산은 어긋나기 쉬워서 뷰에서 떼어냈다.
/// 자르는 영역은 **이미지 기준 단위 사각형(0~1)** 으로 들고 다닌다 — 화면이 회전하거나
/// 크기가 바뀌어도 고른 영역이 그대로 남고, 픽셀로 바꿀 때 배율을 다시 계산할 필요가 없다.
enum CropGeometry {

    /// 컨테이너 안에서 이미지가 실제로 그려지는 사각형 (aspect fit).
    ///
    /// 자르기 좌표의 기준이 되므로 `GeometryReader`로 재는 대신 직접 계산한다 — 재는 시점에
    /// 따라 값이 달라지면 **엉뚱한 영역이 잘린다.**
    static func displayRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }

        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// 단위 사각형(0~1)을 화면 좌표로 편다.
    static func denormalize(_ unit: CGRect, in display: CGRect) -> CGRect {
        CGRect(
            x: display.minX + unit.minX * display.width,
            y: display.minY + unit.minY * display.height,
            width: unit.width * display.width,
            height: unit.height * display.height
        )
    }

    /// 화면 좌표 사각형을 단위 사각형으로 접는다.
    ///
    /// 이미지 밖으로 나간 부분은 잘라내고, 너무 작아지면 최소 크기까지 도로 넓힌다 —
    /// 넓이가 0인 영역을 그대로 두면 자르기가 실패해 **사진이 아예 첨부되지 않는다.**
    static func normalize(_ rect: CGRect, in display: CGRect, minimumSide: CGFloat) -> CGRect {
        guard display.width > 0, display.height > 0 else { return unitFull }

        // 음수 너비(반대 방향으로 끈 경우)를 정방향으로 편다.
        let standardized = rect.standardized

        // 이미지 밖까지 끌었으면 **잘라낸다**. 크기를 유지한 채 안쪽으로 밀면 손가락이 있는
        // 곳과 다른 영역이 잡혀 따라오지 않는 것처럼 보인다.
        let trimmed = standardized.intersection(display)
        var clamped = (trimmed.isNull || trimmed.isEmpty) ? standardized : trimmed

        let minWidth = min(minimumSide, display.width)
        let minHeight = min(minimumSide, display.height)
        if clamped.width < minWidth { clamped.size.width = minWidth }
        if clamped.height < minHeight { clamped.size.height = minHeight }

        // 최소 크기로 넓히다 이미지 밖으로 나가면 안쪽으로 민다.
        clamped.origin.x = min(max(clamped.minX, display.minX), display.maxX - clamped.width)
        clamped.origin.y = min(max(clamped.minY, display.minY), display.maxY - clamped.height)

        return CGRect(
            x: (clamped.minX - display.minX) / display.width,
            y: (clamped.minY - display.minY) / display.height,
            width: clamped.width / display.width,
            height: clamped.height / display.height
        )
    }

    /// 이미지 전체를 가리키는 단위 사각형.
    static let unitFull = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// 사각형을 크기 그대로 컨테이너 안으로 밀어 넣는다 (이동용 — 줄이지 않는다).
    static func slideInside(_ rect: CGRect, container: CGRect) -> CGRect {
        guard container.width >= rect.width, container.height >= rect.height else { return container }
        var moved = rect
        moved.origin.x = min(max(rect.minX, container.minX), container.maxX - rect.width)
        moved.origin.y = min(max(rect.minY, container.minY), container.maxY - rect.height)
        return moved
    }

    /// 단위 사각형 → 원본 픽셀 사각형.
    ///
    /// 픽셀 경계를 넘지 않게 자르고 정수로 맞춘다. `CGImage.cropping(to:)`은 경계를 넘는
    /// 사각형을 받으면 `nil`을 돌려주므로, 여기서 미리 막아야 자르기가 실패하지 않는다.
    static func pixelRect(_ unit: CGRect, pixelSize: CGSize) -> CGRect {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return .zero }

        let bounds = CGRect(origin: .zero, size: pixelSize)
        let scaled = CGRect(
            x: unit.minX * pixelSize.width,
            y: unit.minY * pixelSize.height,
            width: unit.width * pixelSize.width,
            height: unit.height * pixelSize.height
        ).standardized.intersection(bounds)

        // 겹치는 곳이 없으면 `intersection`이 `.null`을 준다. 그럴 땐 전체를 쓴다.
        guard !scaled.isNull, !scaled.isEmpty else { return bounds }

        let integral = scaled.integral.intersection(bounds)
        // 1픽셀보다 얇아지면 자르기가 실패한다. 최소 1픽셀은 남긴다.
        guard !integral.isNull, integral.width >= 1, integral.height >= 1 else {
            return CGRect(
                x: scaled.minX.rounded(.down),
                y: scaled.minY.rounded(.down),
                width: 1,
                height: 1
            ).intersection(bounds)
        }
        return integral
    }
}
