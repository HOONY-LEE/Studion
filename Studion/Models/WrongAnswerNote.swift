import Foundation
import SwiftData

/// 오답노트 카드. 온디바이스 OCR로 추출한 텍스트를 사용자가 확인/수정한 뒤 저장한다.
/// 내신 과목과 모의고사 과목 중 하나에만 연결된다 (둘 다 옵셔널 — 어느 쪽에 속하는지는 생성 시점에 결정).
@Model
final class WrongAnswerNote {
    var ocrRawText: String = ""
    var userEditedText: String = ""
    var causeTagRaw: String = WrongAnswerCauseTag.dontKnow.rawValue
    var englishSubcategoryRaw: String?
    /// 앱 문서 디렉터리에 저장된 원본 이미지 파일명 (CloudKit 자산 처리 전략은 7단계에서 확정).
    var imageFileName: String?
    var createdAt: Date = Date()

    /// 스페이스드 리피티션 (Leitner box): 0=1일, 1=3일, 2=7일, 3=14일, 4=30일.
    var leitnerBoxIndex: Int = 0
    var nextReviewDate: Date = Date()
    var lastReviewedAt: Date?

    var schoolSubject: SchoolSubjectRecord?
    var mockExamSubject: MockExamSubjectRecord?

    var causeTag: WrongAnswerCauseTag {
        get { WrongAnswerCauseTag(rawValue: causeTagRaw) ?? .dontKnow }
        set { causeTagRaw = newValue.rawValue }
    }

    var englishSubcategory: EnglishSubcategory? {
        get { englishSubcategoryRaw.flatMap { EnglishSubcategory(rawValue: $0) } }
        set { englishSubcategoryRaw = newValue?.rawValue }
    }

    init(
        ocrRawText: String = "",
        userEditedText: String = "",
        causeTag: WrongAnswerCauseTag = .dontKnow
    ) {
        self.ocrRawText = ocrRawText
        self.userEditedText = userEditedText
        self.causeTagRaw = causeTag.rawValue
    }
}
