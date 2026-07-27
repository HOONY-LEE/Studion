import Foundation
import SwiftData

/// 모의고사 회차 (예: "2026년 6월 학평"). 등급컷 데이터를 앱이 보유하지 않으므로
/// 회차 이름은 항상 사용자가 직접 입력한다.
@Model
final class MockExamSession {
    var name: String = ""
    var examDate: Date = Date()
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \MockExamSubjectRecord.session)
    var subjectRecords: [MockExamSubjectRecord]? = []

    init(name: String = "", examDate: Date = Date()) {
        self.name = name
        self.examDate = examDate
    }
}
