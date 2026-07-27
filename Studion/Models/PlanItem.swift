import Foundation
import SwiftData

/// 일간 계획/할 일 항목.
@Model
final class PlanItem {
    var title: String = ""
    /// 이 계획이 속한 날짜 (하루 단위 관리 — 시각은 무시하고 day 단위로만 비교).
    var date: Date = Date()
    var isDone: Bool = false
    var createdAt: Date = Date()
    /// 특정 과목과 연관지을 때 사용 (자유 입력 문자열, 과목 마스터 테이블 없음).
    var relatedSubjectName: String?

    init(title: String = "", date: Date = Date()) {
        self.title = title
        self.date = date
    }
}
