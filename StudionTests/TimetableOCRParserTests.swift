import CoreGraphics
import Testing
@testable import Studion

/// 시간표 사진을 요일 × 교시 표로 되돌리는 규칙.
///
/// 이 파서가 틀리면 **수업이 엉뚱한 요일·교시에 들어간다** — 글자를 잘못 읽는 것보다
/// 눈치채기 어렵고 더 나쁘다. 그래서 위치 판단을 촘촘히 검증한다.
@Suite("시간표 사진 읽기")
struct TimetableOCRParserTests {

    // MARK: 도우미

    /// 5일 × 5교시 시간표 사진을 흉내 낸다. 좌표는 왼쪽 위가 원점인 0~1.
    private func box(_ text: String, x: CGFloat, y: CGFloat) -> TimetableTextBox {
        TimetableTextBox(text: text, rect: CGRect(x: x - 0.04, y: y - 0.03, width: 0.08, height: 0.06))
    }

    /// 요일 머리글(맨 위 줄)과 교시 번호(맨 왼쪽 열).
    private var gridFrame: [TimetableTextBox] {
        var boxes: [TimetableTextBox] = []
        let dayNames = ["월", "화", "수", "목", "금"]
        for (index, name) in dayNames.enumerated() {
            boxes.append(box(name, x: 0.25 + CGFloat(index) * 0.16, y: 0.06))
        }
        for number in 1...5 {
            boxes.append(box("\(number)", x: 0.08, y: 0.2 + CGFloat(number - 1) * 0.15))
        }
        return boxes
    }

    private func contentX(day: Int) -> CGFloat { 0.25 + CGFloat(day) * 0.16 }
    private func contentY(period: Int) -> CGFloat { 0.2 + CGFloat(period - 1) * 0.15 }

    // MARK: 기본 배치

    @Test("과목이 찍힌 요일·교시 칸으로 들어간다")
    func placesSubjectsInTheirCells() {
        let boxes = gridFrame + [
            box("국어", x: contentX(day: 0), y: contentY(period: 1)),
            box("수학", x: contentX(day: 2), y: contentY(period: 3)),
            box("영어", x: contentX(day: 4), y: contentY(period: 5)),
        ]

        let result = TimetableOCRParser.parse(boxes)

        #expect(result.cells.count == 3)
        #expect(result.cells.contains(.init(dayIndex: 0, periodNumber: 1, title: "국어", location: "")))
        #expect(result.cells.contains(.init(dayIndex: 2, periodNumber: 3, title: "수학", location: "")))
        #expect(result.cells.contains(.init(dayIndex: 4, periodNumber: 5, title: "영어", location: "")))
    }

    @Test("요일 머리글과 교시 번호는 수업으로 오해하지 않는다")
    func gridLabelsAreNotSubjects() {
        // 머리글까지 수업으로 넣으면 월요일마다 "월"이라는 과목이 생긴다.
        let result = TimetableOCRParser.parse(gridFrame)
        #expect(result.cells.isEmpty)
        #expect(result.foundDayCount == 5)
        #expect(result.foundPeriodCount == 5)
    }

    @Test("빈 칸은 수업을 만들지 않는다")
    func emptyCellsProduceNothing() {
        let boxes = gridFrame + [box("국어", x: contentX(day: 0), y: contentY(period: 1))]
        let result = TimetableOCRParser.parse(boxes)
        #expect(result.cells.count == 1)
    }

    @Test("표 밖의 글자는 버린다")
    func textOutsideGridIsIgnored() {
        // 시간표 사진에는 학교 이름·학년 같은 것이 같이 찍힌다.
        let boxes = gridFrame + [
            box("○○고등학교 1학년 3반", x: 0.5, y: -0.2),
            box("국어", x: contentX(day: 0), y: contentY(period: 1)),
        ]
        let result = TimetableOCRParser.parse(boxes)
        #expect(result.cells.map(\.title) == ["국어"])
    }

    // MARK: 교실

    @Test("과목 아래 붙은 교실을 따로 담는다")
    func splitsLocationBelowSubject() {
        let boxes = gridFrame + [
            box("물리학", x: contentX(day: 1), y: contentY(period: 2) - 0.02),
            box("과학실", x: contentX(day: 1), y: contentY(period: 2) + 0.02),
        ]

        let result = TimetableOCRParser.parse(boxes)
        #expect(result.cells == [
            .init(dayIndex: 1, periodNumber: 2, title: "물리학", location: "과학실")
        ])
    }

    @Test("반 번호도 교실로 본다")
    func classNumberIsLocation() {
        #expect(TimetableOCRParser.looksLikeLocation("3-5"))
        #expect(TimetableOCRParser.looksLikeLocation("(2-11)"))
        #expect(TimetableOCRParser.looksLikeLocation("음악실"))
        #expect(TimetableOCRParser.looksLikeLocation("체육관"))
        #expect(!TimetableOCRParser.looksLikeLocation("확률과 통계"))
    }

    @Test("교실처럼 보이는 줄이 없으면 전부 과목명이다")
    func keepsEverythingWhenNoLocation() {
        // 글자를 잃는 것보다 잘못 붙는 편이 낫다 — 사라진 글자는 다시 타이핑해야 한다.
        let (title, location) = TimetableOCRParser.splitTitleAndLocation(["확률과", "통계"])
        #expect(title == "확률과 통계")
        #expect(location.isEmpty)
    }

    @Test("교실 표기의 괄호는 벗겨낸다")
    func stripsBracketsFromLocation() {
        let (title, location) = TimetableOCRParser.splitTitleAndLocation(["미술", "(미술실)"])
        #expect(title == "미술")
        #expect(location == "미술실")
    }

    @Test("호실 번호와 층 표기도 교실로 본다")
    func roomCodesAreLocation() {
        #expect(TimetableOCRParser.looksLikeLocation("301"))
        #expect(TimetableOCRParser.looksLikeLocation("2층"))
        #expect(TimetableOCRParser.looksLikeLocation("본관"))
        #expect(TimetableOCRParser.looksLikeLocation("A-102"))
        #expect(TimetableOCRParser.looksLikeLocation("운동장"))
        // 한두 자리 숫자는 교시·차시와 헷갈리므로 교실로 보지 않는다.
        #expect(!TimetableOCRParser.looksLikeLocation("3"))
        #expect(!TimetableOCRParser.looksLikeLocation("12"))
        // 숫자가 없는 하이픈은 반 번호가 아니다.
        #expect(!TimetableOCRParser.looksLikeLocation("확률-통계"))
    }

    @Test("한 줄 안에 괄호로 붙은 교실을 떼어낸다")
    func splitsInlineLocation() {
        let (title, location) = TimetableOCRParser.splitTitleAndLocation(["수학(과학실)"])
        #expect(title == "수학")
        #expect(location == "과학실")

        let (title2, location2) = TimetableOCRParser.splitTitleAndLocation(["국어 (3-5)"])
        #expect(title2 == "국어")
        #expect(location2 == "3-5")
    }

    @Test("과목명의 일부인 괄호는 떼지 않는다")
    func keepsNonLocationParentheses() {
        // "심화"는 교실로 보이지 않으므로 과목명에 그대로 남아야 한다.
        let (title, location) = TimetableOCRParser.splitTitleAndLocation(["확률과 통계(심화)"])
        #expect(title == "확률과 통계(심화)")
        #expect(location.isEmpty)
    }

    // MARK: 글자 해석

    @Test("요일 표기를 여러 형태로 알아본다")
    func recognizesWeekdayLabels() {
        #expect(TimetableOCRParser.weekdayIndex(of: "월") == 0)
        #expect(TimetableOCRParser.weekdayIndex(of: "월요일") == 0)
        #expect(TimetableOCRParser.weekdayIndex(of: "금") == 4)
        #expect(TimetableOCRParser.weekdayIndex(of: "Fri") == 4)
        #expect(TimetableOCRParser.weekdayIndex(of: "국어") == nil)
    }

    @Test("교시 번호를 여러 형태로 알아본다")
    func recognizesPeriodNumbers() {
        #expect(TimetableOCRParser.periodNumber(of: "3") == 3)
        #expect(TimetableOCRParser.periodNumber(of: "3교시") == 3)
        #expect(TimetableOCRParser.periodNumber(of: "3.") == 3)
        #expect(TimetableOCRParser.periodNumber(of: "0") == nil)
        #expect(TimetableOCRParser.periodNumber(of: "99") == nil)
        #expect(TimetableOCRParser.periodNumber(of: "국어") == nil)
    }

    @Test("과목명에 든 숫자는 교시로 오해하지 않는다")
    func numbersInsideSubjectAreNotPeriods() {
        // "물리학1"은 교시 칸이 아니라 수업 칸에 있다 — 위치로 걸러야 한다.
        let boxes = gridFrame + [
            box("물리학1", x: contentX(day: 3), y: contentY(period: 4)),
        ]
        let result = TimetableOCRParser.parse(boxes)
        #expect(result.foundPeriodCount == 5)
        #expect(result.cells == [
            .init(dayIndex: 3, periodNumber: 4, title: "물리학1", location: "")
        ])
    }

    // MARK: 격자를 못 세우는 경우

    @Test("요일을 못 찾으면 격자 실패로 알린다")
    func missingWeekdaysFailsGrid() {
        // 시간표가 아닌 사진을 넣었을 때 엉뚱한 수업을 만들어내면 안 된다.
        let boxes = [box("국어", x: 0.3, y: 0.3), box("수학", x: 0.5, y: 0.5)]
        let result = TimetableOCRParser.parse(boxes)
        #expect(result.failedToBuildGrid)
        #expect(result.cells.isEmpty)
    }

    @Test("교시를 못 찾으면 격자 실패로 알린다")
    func missingPeriodsFailsGrid() {
        var boxes: [TimetableTextBox] = []
        for (index, name) in ["월", "화", "수"].enumerated() {
            boxes.append(box(name, x: 0.25 + CGFloat(index) * 0.16, y: 0.06))
        }
        boxes.append(box("국어", x: 0.25, y: 0.3))

        let result = TimetableOCRParser.parse(boxes)
        #expect(result.failedToBuildGrid)
    }

    @Test("빈 입력은 조용히 빈 결과다")
    func emptyInput() {
        let result = TimetableOCRParser.parse([])
        #expect(result.cells.isEmpty)
        #expect(result.failedToBuildGrid)
    }

    // MARK: 머리글을 못 읽었을 때

    @Test("요일 하나를 못 읽어도 그 요일 수업을 잃지 않는다")
    func recoversMissingWeekdayColumn() {
        // 실제로 겪은 문제 — Vision이 "목" 한 글자를 놓쳐 목요일 수업이 통째로 사라졌다.
        // 하루치가 조용히 없어지는 것이라 사용자가 알아채기 어렵다.
        let withoutThursday = gridFrame.filter { $0.text != "목" }
        let boxes = withoutThursday + [
            box("확률과통계", x: contentX(day: 3), y: contentY(period: 2)),
        ]

        let result = TimetableOCRParser.parse(boxes)
        #expect(result.foundDayCount == 5)
        #expect(result.cells == [
            .init(dayIndex: 3, periodNumber: 2, title: "확률과통계", location: "")
        ])
    }

    @Test("찾은 요일 바깥으로는 열을 만들지 않는다")
    func doesNotExtrapolateBeyondFoundDays() {
        // 없는 요일을 지어내면 엉뚱한 수업이 붙는다. 사이만 메운다.
        var boxes: [TimetableTextBox] = []
        for (index, name) in ["월", "화", "수"].enumerated() {
            boxes.append(box(name, x: 0.25 + CGFloat(index) * 0.16, y: 0.06))
        }
        for number in 1...3 {
            boxes.append(box("\(number)", x: 0.08, y: 0.2 + CGFloat(number - 1) * 0.15))
        }

        let result = TimetableOCRParser.parse(boxes)
        #expect(result.foundDayCount == 3)
    }

    @Test("가운데 요일 여럿을 못 읽어도 자리를 맞춘다")
    func fillsMultipleMissingColumns() {
        let sparse = gridFrame.filter { $0.text != "화" && $0.text != "목" }
        let boxes = sparse + [
            box("화1", x: contentX(day: 1), y: contentY(period: 1)),
            box("목1", x: contentX(day: 3), y: contentY(period: 1)),
        ]

        let result = TimetableOCRParser.parse(boxes)
        #expect(result.foundDayCount == 5)
        #expect(result.cells.map(\.dayIndex).sorted() == [1, 3])
    }

    // MARK: 사진이 반듯하지 않을 때

    @Test("칸 안에서 글자가 조금 치우쳐도 같은 칸으로 간다")
    func toleratesSlightOffset() {
        // 손으로 찍은 사진은 완벽히 반듯하지 않다.
        let boxes = gridFrame + [
            box("국어", x: contentX(day: 2) + 0.03, y: contentY(period: 3) + 0.02),
        ]
        let result = TimetableOCRParser.parse(boxes)
        #expect(result.cells == [
            .init(dayIndex: 2, periodNumber: 3, title: "국어", location: "")
        ])
    }

    @Test("한 칸에 여러 줄이 있으면 위에서 아래 순서로 잇는다")
    func joinsLinesTopToBottom() {
        let boxes = gridFrame + [
            box("통합", x: contentX(day: 0), y: contentY(period: 2) - 0.02),
            box("사회", x: contentX(day: 0), y: contentY(period: 2) + 0.02),
        ]
        let result = TimetableOCRParser.parse(boxes)
        #expect(result.cells.first?.title == "통합 사회")
    }

    @Test("결과는 교시·요일 순으로 정렬된다")
    func resultsAreSorted() {
        // 확인 화면이 시간표 읽는 순서대로 보여야 한다.
        let boxes = gridFrame + [
            box("금5", x: contentX(day: 4), y: contentY(period: 5)),
            box("월1", x: contentX(day: 0), y: contentY(period: 1)),
            box("월3", x: contentX(day: 0), y: contentY(period: 3)),
        ]
        let result = TimetableOCRParser.parse(boxes)
        #expect(result.cells.map(\.title) == ["월1", "월3", "금5"])
    }
}
