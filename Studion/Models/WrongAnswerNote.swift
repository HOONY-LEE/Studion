import Foundation
import SwiftData

/// 오답노트 카드. 온디바이스 OCR로 추출한 텍스트를 사용자가 확인/수정한 뒤 저장한다.
/// 내신 과목과 모의고사 과목 중 하나에만 연결된다 (둘 다 옵셔널 — 어느 쪽에 속하는지는 생성 시점에 결정).
@Model
final class WrongAnswerNote {
    var ocrRawText: String = ""
    /// 지문·문제·선택지를 합친 한 덩어리 텍스트.
    ///
    /// 구조화 필드가 생긴 뒤에도 유지한다 — 목록 미리보기와 백업이 통짜 텍스트를 쓰고,
    /// 구조를 나누기 전에 만든 옛 노트에는 이 값밖에 없기 때문이다. 저장할 때
    /// 구조화 필드로부터 다시 만들어 넣으므로 둘이 어긋나지 않는다.
    var userEditedText: String = ""
    var causeTagRaw: String = WrongAnswerCauseTag.dontKnow.rawValue
    var englishSubcategoryRaw: String?

    /// 문제 앞에 딸려오는 지문. 없으면 빈 문자열.
    var passageText: String = ""
    /// 실제로 묻는 문장.
    var promptText: String = ""
    /// 객관식 선택지. 서술형이면 빈 배열.
    ///
    /// `Question`과 같은 이유로 배열이다 — 개수 자체가 곧 선택지 수이므로
    /// "중간이 비어 있는" 상태가 만들어지지 않는다.
    var choices: [String] = []
    /// 왜 틀렸는지에 대한 사용자의 메모 (선택).
    var explanation: String = ""

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

    /// 객관식 카드로 저장했는지. 선택지가 2개 이상일 때만 참이다.
    var isMultipleChoice: Bool = false
    /// 정답 선택지의 0-based 인덱스. 사용자가 직접 지정하며, 모르면 비워둔다.
    /// 앱이 정답을 추정하거나 만들어내지 않는다.
    var correctChoiceIndex: Int?

    /// 화면에 보여줄 지문·문제·선택지.
    ///
    /// 구조화 필드가 채워져 있으면 그대로 쓴다. 비어 있으면 구조를 나누기 전에 만든 옛
    /// 노트이므로 저장된 한 덩어리 텍스트를 그때그때 나눠 읽는다 — 일괄 마이그레이션 없이도
    /// 옛 노트가 새 화면에서 제대로 보이고, 사용자가 그 노트를 열어 저장하면 그때 정착된다.
    var content: OCRQuestionSplitter.Result {
        if !promptText.trimmed.isEmpty || !choices.isEmpty {
            return OCRQuestionSplitter.Result(
                passage: passageText, prompt: promptText, choices: choices
            )
        }
        return OCRQuestionSplitter.split(userEditedText)
    }

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
