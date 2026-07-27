import Testing
@testable import Studion

@Suite("GradingSystemType")
struct GradingSystemTypeTests {
    @Test("5등급제 경계값은 5개, 마지막은 1.0")
    func fiveTierBoundaries() {
        let boundaries = GradingSystemType.fiveTier.cumulativeBoundaries
        #expect(boundaries.count == 5)
        #expect(boundaries.last == 1.0)
    }

    @Test("9등급제 경계값은 9개, 마지막은 1.0")
    func nineTierBoundaries() {
        let boundaries = GradingSystemType.nineTier.cumulativeBoundaries
        #expect(boundaries.count == 9)
        #expect(boundaries.last == 1.0)
    }
}
