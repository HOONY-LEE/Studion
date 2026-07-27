import Foundation
import SwiftData

/// 사용자의 학년/입학연도/기본 등급제 설정. 앱 전체에서 단일 인스턴스로 사용한다.
@Model
final class AcademicProfile {
    var admissionYear: Int = 2025
    var gradeLevel: Int = 1
    var gradingSystemTypeRaw: String = GradingSystemType.fiveTier.rawValue
    var createdAt: Date = Date()

    var gradingSystemType: GradingSystemType {
        get { GradingSystemType(rawValue: gradingSystemTypeRaw) ?? .fiveTier }
        set { gradingSystemTypeRaw = newValue.rawValue }
    }

    init(
        admissionYear: Int = 2025,
        gradeLevel: Int = 1,
        gradingSystemType: GradingSystemType = .fiveTier
    ) {
        self.admissionYear = admissionYear
        self.gradeLevel = gradeLevel
        self.gradingSystemTypeRaw = gradingSystemType.rawValue
    }
}
