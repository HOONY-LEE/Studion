import Testing
@testable import Studion

/// 시간표 과목 색 배정.
///
/// "과목별로 색이 다르다"가 이 기능의 전부라, **같은 과목은 늘 같은 색**이고
/// **다른 과목은 되도록 다른 색**이어야 한다.
@Suite("시간표 과목 색")
struct TimetableColorAssignerTests {

    @Test("과목마다 다른 색을 준다")
    func differentSubjectsGetDifferentColors() {
        let assigned = TimetableColorAssigner.assign(titles: ["국어", "수학", "영어"])
        #expect(Set(assigned.values).count == 3)
    }

    @Test("같은 과목은 언제나 같은 색이다")
    func sameSubjectKeepsOneColor() {
        // 월요일 국어와 수요일 국어가 다른 색이면 색으로 과목을 알아볼 수 없다.
        let assigned = TimetableColorAssigner.assign(titles: ["국어", "수학", "국어", "국어"])
        #expect(assigned.count == 2)
        #expect(assigned[TimetableColorAssigner.key(for: "국어")] != nil)
    }

    @Test("띄어쓰기만 다른 과목은 같은 과목으로 본다")
    func ignoresWhitespaceDifferences() {
        // 사진에서 읽은 이름과 손으로 적은 이름이 띄어쓰기만 다른 경우가 흔하다.
        let assigned = TimetableColorAssigner.assign(titles: ["확률과 통계", "확률과통계"])
        #expect(assigned.count == 1)
    }

    @Test("이미 색이 있는 과목은 그 색을 그대로 쓴다")
    func reusesExistingColor() {
        let existing = [TimetableColorAssigner.key(for: "국어"): 7]
        let assigned = TimetableColorAssigner.assign(titles: ["국어", "수학"], existing: existing)

        #expect(assigned[TimetableColorAssigner.key(for: "국어")] == 7)
        #expect(assigned[TimetableColorAssigner.key(for: "수학")] != 7)
    }

    @Test("색이 팔레트 수보다 많아지면 가장 덜 쓰인 색부터 다시 쓴다")
    func reusesLeastUsedWhenPaletteRunsOut() {
        let many = (1...(TimetableColorAssigner.paletteCount + 3)).map { "과목\($0)" }
        let assigned = TimetableColorAssigner.assign(titles: many)

        #expect(assigned.count == many.count)
        // 팔레트를 한 바퀴 돌아도 특정 색에 몰리지 않는다.
        var counts: [Int: Int] = [:]
        for index in assigned.values { counts[index, default: 0] += 1 }
        #expect(counts.values.max()! - counts.values.min()! <= 1)
    }

    @Test("색 번호는 팔레트 범위 안에 있다")
    func colorsStayInRange() {
        let assigned = TimetableColorAssigner.assign(titles: (1...30).map { "과목\($0)" })
        #expect(assigned.values.allSatisfy { (0..<TimetableColorAssigner.paletteCount).contains($0) })
    }

    @Test("빈 이름은 색을 받지 않는다")
    func emptyTitlesAreSkipped() {
        let assigned = TimetableColorAssigner.assign(titles: ["", "   ", "국어"])
        #expect(assigned.count == 1)
    }

    @Test("같은 입력이면 같은 결과가 나온다")
    func isDeterministic() {
        // 화면을 다시 그릴 때마다 색이 바뀌면 안 된다.
        let titles = ["국어", "수학", "영어", "한국사"]
        #expect(TimetableColorAssigner.assign(titles: titles) == TimetableColorAssigner.assign(titles: titles))
    }

    // MARK: 기존 수업에서 색 모으기

    @Test("기존 수업에서 과목별 색을 모은다")
    func collectsExistingAssignments() {
        let existing = TimetableColorAssigner.existingAssignments(from: [
            ("국어", 2), ("수학", 5), ("국어", 2),
        ])
        #expect(existing == [
            TimetableColorAssigner.key(for: "국어"): 2,
            TimetableColorAssigner.key(for: "수학"): 5,
        ])
    }

    @Test("한 과목에 색이 여러 개면 가장 작은 번호로 통일한다")
    func collapsesConflictingColors() {
        // 무엇을 고르든 상관없지만 매번 같은 답이 나와야 화면이 깜빡이지 않는다.
        let existing = TimetableColorAssigner.existingAssignments(from: [("국어", 6), ("국어", 3)])
        #expect(existing[TimetableColorAssigner.key(for: "국어")] == 3)
    }

    @Test("범위 밖 색 번호는 무시한다")
    func ignoresOutOfRangeColors() {
        let existing = TimetableColorAssigner.existingAssignments(from: [("국어", 99), ("수학", -1)])
        #expect(existing.isEmpty)
    }
}
