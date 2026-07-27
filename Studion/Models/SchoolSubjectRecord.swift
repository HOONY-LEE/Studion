import Foundation
import SwiftData

/// 내신 과목 하나의 학기별 성적 기록.
/// 고교학점제 특성상 과목 목록을 앱에 고정 내장하지 않고 사용자가 직접 추가한다.
@Model
final class SchoolSubjectRecord {
    var subjectName: String = ""
    var creditUnits: Double = 0
    var rawScore: Double?
    var subjectAverage: Double?
    var stdDeviation: Double?
    var studentCount: Int?
    var evaluationTypeRaw: String = SchoolSubjectEvaluationType.achievementAndRank.rawValue
    var achievementLevelRaw: String?
    /// 석차등급. evaluationType이 achievementOnly인 예외 과목은 nil로 둔다.
    var rankGrade: Int?
    /// 이 학기 이 과목의 목표 등급 (사용자 입력).
    var targetGrade: Int?
    var createdAt: Date = Date()

    var semester: Semester?

    @Relationship(deleteRule: .cascade, inverse: \WrongAnswerNote.schoolSubject)
    var wrongAnswerNotes: [WrongAnswerNote]? = []

    var evaluationType: SchoolSubjectEvaluationType {
        get { SchoolSubjectEvaluationType(rawValue: evaluationTypeRaw) ?? .achievementAndRank }
        set { evaluationTypeRaw = newValue.rawValue }
    }

    var achievementLevel: AchievementLevel? {
        get { achievementLevelRaw.flatMap { AchievementLevel(rawValue: $0) } }
        set { achievementLevelRaw = newValue?.rawValue }
    }

    init(
        subjectName: String = "",
        creditUnits: Double = 0,
        evaluationType: SchoolSubjectEvaluationType = .achievementAndRank,
        semester: Semester? = nil
    ) {
        self.subjectName = subjectName
        self.creditUnits = creditUnits
        self.evaluationTypeRaw = evaluationType.rawValue
        self.semester = semester
    }
}
