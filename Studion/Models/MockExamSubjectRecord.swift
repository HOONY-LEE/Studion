import Foundation
import SwiftData

/// 모의고사 회차 내 과목별 성적. 원점수/표준점수/백분위/등급 모두 사용자가 직접 입력한다
/// (앱이 등급컷을 추정하지 않는다).
@Model
final class MockExamSubjectRecord {
    var subjectName: String = ""
    var rawScore: Double?
    var standardScore: Double?
    var percentile: Double?
    var grade: Int?
    var createdAt: Date = Date()

    var session: MockExamSession?

    @Relationship(deleteRule: .cascade, inverse: \WrongAnswerNote.mockExamSubject)
    var wrongAnswerNotes: [WrongAnswerNote]? = []

    init(subjectName: String = "", session: MockExamSession? = nil) {
        self.subjectName = subjectName
        self.session = session
    }
}
