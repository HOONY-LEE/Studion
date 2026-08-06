import CoreGraphics
import Testing
@testable import Studion

/// 사진 자르기 좌표 계산.
///
/// 여기가 틀리면 **엉뚱한 곳이 잘리거나 자르기가 실패해 사진이 아예 첨부되지 않는다.**
/// 화면에서 눈으로 잡기 어려운 경계들을 여기서 잡는다.
@Suite("사진 자르기 좌표")
struct CropGeometryTests {

    // MARK: 표시 영역

    @Test("가로로 긴 사진은 위아래에 여백이 남는다")
    func wideImageGetsVerticalLetterbox() {
        let rect = CropGeometry.displayRect(
            imageSize: CGSize(width: 200, height: 100),
            in: CGSize(width: 100, height: 100)
        )
        #expect(rect == CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    @Test("세로로 긴 사진은 좌우에 여백이 남는다")
    func tallImageGetsHorizontalLetterbox() {
        let rect = CropGeometry.displayRect(
            imageSize: CGSize(width: 100, height: 200),
            in: CGSize(width: 100, height: 100)
        )
        #expect(rect == CGRect(x: 25, y: 0, width: 50, height: 100))
    }

    @Test("크기가 0이면 빈 사각형이다 — 레이아웃 전에 계산될 수 있다")
    func zeroSizesAreSafe() {
        #expect(CropGeometry.displayRect(imageSize: .zero, in: CGSize(width: 10, height: 10)) == .zero)
        #expect(CropGeometry.displayRect(imageSize: CGSize(width: 10, height: 10), in: .zero) == .zero)
    }

    // MARK: 단위 사각형 ↔ 화면 좌표

    @Test("폈다가 다시 접으면 그대로다")
    func denormalizeRoundTrips() {
        let display = CGRect(x: 20, y: 40, width: 200, height: 400)
        let unit = CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25)

        let screen = CropGeometry.denormalize(unit, in: display)
        #expect(screen == CGRect(x: 70, y: 240, width: 100, height: 100))

        let back = CropGeometry.normalize(screen, in: display, minimumSide: 10)
        #expect(back == unit)
    }

    @Test("이미지 밖으로 나간 영역은 안쪽으로 들어온다")
    func outOfBoundsIsPulledIn() {
        let display = CGRect(x: 0, y: 0, width: 100, height: 100)
        let unit = CropGeometry.normalize(
            CGRect(x: -50, y: -50, width: 60, height: 60), in: display, minimumSide: 10
        )
        #expect(unit.minX >= 0)
        #expect(unit.minY >= 0)
        #expect(unit.maxX <= 1)
        #expect(unit.maxY <= 1)
    }

    @Test("이미지 밖까지 끈 만큼은 잘려나간다")
    func overshootIsTrimmedNotSlid() {
        // 크기를 유지한 채 안쪽으로 밀면 손가락 위치와 다른 영역이 잡힌다.
        let display = CGRect(x: 0, y: 100, width: 100, height: 100)
        let unit = CropGeometry.normalize(
            CGRect(x: 20, y: 0, width: 60, height: 150), in: display, minimumSide: 10
        )
        // 세로는 위쪽 100pt가 잘려 100~150만 남는다.
        #expect(unit == CGRect(x: 0.2, y: 0, width: 0.6, height: 0.5))
    }

    @Test("이미지보다 큰 영역은 이미지 전체가 된다")
    func oversizedBecomesFullImage() {
        let display = CGRect(x: 0, y: 0, width: 100, height: 100)
        let unit = CropGeometry.normalize(
            CGRect(x: -50, y: -50, width: 300, height: 300), in: display, minimumSide: 10
        )
        #expect(unit == CropGeometry.unitFull)
    }

    @Test("반대 방향으로 끌어도 정상 영역이 된다")
    func negativeSizeIsStraightened() {
        let display = CGRect(x: 0, y: 0, width: 100, height: 100)
        let unit = CropGeometry.normalize(
            CGRect(x: 80, y: 80, width: -60, height: -60), in: display, minimumSide: 10
        )
        #expect(unit == CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6))
    }

    @Test("너무 작게 끌면 최소 크기까지 넓어진다")
    func tinyRectGrowsToMinimum() {
        // 넓이 0짜리 영역을 그대로 두면 자르기가 실패해 사진이 통째로 사라진다.
        let display = CGRect(x: 0, y: 0, width: 200, height: 200)
        let unit = CropGeometry.normalize(.zero, in: display, minimumSide: 60)
        #expect(unit.width == 0.3)
        #expect(unit.height == 0.3)
    }

    @Test("최소 크기가 이미지보다 크면 이미지 전체가 된다")
    func minimumNeverExceedsImage() {
        let display = CGRect(x: 0, y: 0, width: 40, height: 40)
        let unit = CropGeometry.normalize(.zero, in: display, minimumSide: 100)
        #expect(unit == CropGeometry.unitFull)
    }

    // MARK: 이동

    @Test("옮길 때는 크기를 줄이지 않고 안쪽으로 민다")
    func slideKeepsSize() {
        let container = CGRect(x: 0, y: 0, width: 100, height: 100)
        let moved = CropGeometry.slideInside(
            CGRect(x: 80, y: -20, width: 40, height: 40), container: container
        )
        #expect(moved == CGRect(x: 60, y: 0, width: 40, height: 40))
    }

    @Test("영역이 컨테이너보다 크면 컨테이너에 맞춘다")
    func slideClampsOversized() {
        let container = CGRect(x: 0, y: 0, width: 100, height: 100)
        let moved = CropGeometry.slideInside(
            CGRect(x: -10, y: -10, width: 200, height: 200), container: container
        )
        #expect(moved == container)
    }

    // MARK: 픽셀 좌표

    @Test("단위 사각형이 원본 픽셀로 펴진다")
    func pixelRectScales() {
        let rect = CropGeometry.pixelRect(
            CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25),
            pixelSize: CGSize(width: 400, height: 800)
        )
        #expect(rect == CGRect(x: 100, y: 400, width: 200, height: 200))
    }

    @Test("픽셀 경계를 넘지 않는다")
    func pixelRectStaysInBounds() {
        // `CGImage.cropping(to:)`은 경계를 넘는 사각형에 nil을 준다 — 그러면 자르기가 실패한다.
        let size = CGSize(width: 100, height: 100)
        let rect = CropGeometry.pixelRect(
            CGRect(x: 0.5, y: 0.5, width: 2, height: 2), pixelSize: size
        )
        #expect(rect.maxX <= size.width)
        #expect(rect.maxY <= size.height)
        #expect(rect.width >= 1)
        #expect(rect.height >= 1)
    }

    @Test("정수 픽셀로 맞춰진다")
    func pixelRectIsIntegral() {
        let rect = CropGeometry.pixelRect(
            CGRect(x: 0.111, y: 0.333, width: 0.222, height: 0.444),
            pixelSize: CGSize(width: 333, height: 777)
        )
        #expect(rect == rect.integral)
    }

    @Test("영역이 비어도 1픽셀 이상은 남는다")
    func pixelRectNeverEmpty() {
        let rect = CropGeometry.pixelRect(.zero, pixelSize: CGSize(width: 100, height: 100))
        #expect(rect.width >= 1)
        #expect(rect.height >= 1)
    }

    @Test("이미지 전체를 고르면 픽셀 전체가 나온다")
    func fullUnitCoversWholeImage() {
        let size = CGSize(width: 1234, height: 567)
        let rect = CropGeometry.pixelRect(CropGeometry.unitFull, pixelSize: size)
        #expect(rect == CGRect(origin: .zero, size: size))
    }

    @Test("픽셀 크기가 0이면 빈 사각형이다")
    func zeroPixelSizeIsSafe() {
        #expect(CropGeometry.pixelRect(CropGeometry.unitFull, pixelSize: .zero) == .zero)
    }
}
