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

    init(year: Int = 2025, term: Int = 1, gradingSystemType: GradingSystemType = .fiveTier) {
        self.year = year
        self.term = term
        self.gradingSystemTypeRaw = gradingSystemType.rawValue
    }
}
