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

    /// 원본 이미지. SwiftData가 외부 파일로 분리 저장하고 CloudKit이 자산으로 동기화한다.
    /// 저장 전 리사이즈·JPEG 압축으로 용량을 억제한다.
    @Attribute(.externalStorage) var imageData: Data?

    var createdAt: Date = Date()

    /// 스페이스드 리피티션 (Leitner box): 0=1일, 1=3일, 2=7일, 3=14일, 4=30일.
    var leitnerBoxIndex: Int = 0
    var nextReviewDate: Date = Date()
    var lastReviewedAt: Date?

    var schoolSubject: SchoolSubjectRecord?
    var mockExamSubject: MockExamSubjectRecord?

    /// 사용자가 "객관식으로 저장"을 확인했는지. 선택지 자체는 별도로 저장하지 않고
    /// `userEditedText`에서 `MultipleChoiceParser`로 그때그때 다시 뽑아낸다 —
    /// 텍스트를 나중에 고쳐도 선택지가 따로 놀며 어긋나는 상태가 생기지 않는다.
    var isMultipleChoice: Bool = false
    /// 정답 선택지의 0-based 인덱스. 사용자가 직접 지정하며, 모르면 비워둔다.
    /// 앱이 정답을 추정하거나 만들어내지 않는다.
    var correctChoiceIndex: Int?

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
