import Foundation
import SwiftData

/// 문제 모음집. 퀴즐렛의 "세트"에 해당하며 하위에 문제 카드를 갖는다.
///
/// 명세: `docs/08-question-bank.md` §2
@Model
final class QuestionSet {
    var title: String = ""
    /// `description`은 `NSObject` 계열과 이름이 겹칠 수 있어 접두사를 붙인다.
    var setDescription: String = ""
    /// 과목. 자유 입력이며 마스터 테이블을 두지 않는다 (앱 전체 규칙).
    var subjectName: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Question.questionSet)
    var questions: [Question]? = []

    // MARK: - 공유 대비 (B단계용)
    //
    // 값이 비어 있어도 로컬 사용에 아무 영향이 없어야 한다.
    // 서버 연동 시점의 미결정 사항은 docs/08-question-bank.md §0 참조.

    /// 표시용 작성자 이름. **이메일·실명을 넣지 않는다.**
    var authorDisplayName: String = ""
    /// 서버에 올라간 경우의 식별자. `nil`이면 이 기기에만 있는 문제집이다.
    var remoteID: String?
    var isPublished: Bool = false

    /// `orderIndex` 순으로 정렬된 문제. 뷰가 정렬 규칙을 각자 갖지 않도록 여기서 한 번만 정한다.
    var sortedQuestions: [Question] {
        (questions ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    var questionCount: Int { questions?.count ?? 0 }

    init(title: String = "", setDescription: String = "", subjectName: String = "") {
        self.title = title
        self.setDescription = setDescription
        self.subjectName = subjectName
    }

    /// 문제를 더하거나 고칠 때 호출해 수정 시각을 갱신한다.
    func touch() {
        updatedAt = Date()
    }
}
