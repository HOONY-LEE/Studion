import Foundation
import SwiftData

/// 학기 단위 (예: 고1-1학기). 내신 과목 기록들을 묶는다.
@Model
final class Semester {
    var year: Int = 2025
    var term: Int = 1
    var gradingSystemTypeRaw: String = GradingSystemType.fiveTier.rawValue
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SchoolSubjectRecord.semester)
    var subjectRecords: [SchoolSubjectRecord]? = []

    var gradingSystemType: GradingSystemType {
        get { GradingSystemType(rawValue: gradingSystemTypeRaw) ?? .fiveTier }
        set { gradingSystemTypeRaw = newValue.rawValue }
    }

    /// 학기 선택 UI에 표시할 이름 (예: "2025학년도 1학기").
    var displayName: String {
        String(localized: "\(String(year))학년도 \(term)학기")
    }

    init(year: Int = 2025, term: Int = 1, gradingSystemType: GradingSystemType = .fiveTier) {
        self.year = year
        self.term = term
        self.gradingSystemTypeRaw = gradingSystemType.rawValue
    }
}
