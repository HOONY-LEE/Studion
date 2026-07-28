import Foundation
import SwiftData

/// 문제 카드 한 장.
///
/// 여러 타입을 하나의 객체로 감당한다. 타입마다 쓰는 필드가 다르고, 쓰지 않는 필드는 비어 있다.
/// 어떤 타입이 어떤 필드를 쓰는지는 `docs/08-question-bank.md` §3 표를 따른다.
@Model
final class Question {
    var typeRaw: String = QuestionType.flashcard.rawValue
    /// 모음집 안에서의 순서.
    var orderIndex: Int = 0

    /// 문제 본문 (카드의 앞면).
    var prompt: String = ""
    /// 보기 지문. 문제와 별개로 길게 딸려오는 글이 있을 때 쓴다.
    var passageText: String = ""

    /// 객관식 선택지. **최대 5개** (UI에서 제한).
    ///
    /// `choice1`~`choice5`를 따로 두지 않는 이유: 3지선다·5지선다가 섞여 있는데 개별 필드로 두면
    /// "중간이 비어 있는" 잘못된 상태가 만들어질 수 있다. 배열은 개수 자체가 곧 선택지 수다.
    var choices: [String] = []
    /// 정답 선택지의 0-based 인덱스. `nil`이면 정답을 지정하지 않은 것이며 채점하지 않는다.
    var correctChoiceIndex: Int?

    /// 텍스트 정답. 복수 정답을 허용하므로 배열이다 (예: "사과", "apple").
    /// 플래시카드는 이 배열의 첫 값을 뒷면으로 보여준다.
    var acceptedAnswers: [String] = []

    var explanation: String = ""
    var hint: String = ""

    /// 문제에 딸린 이미지. 오답노트와 같은 방식으로 외부 저장한다.
    @Attribute(.externalStorage) var questionImageData: Data?
    /// 해설에 딸린 도움 설명 이미지.
    @Attribute(.externalStorage) var explanationImageData: Data?

    var createdAt: Date = Date()

    var questionSet: QuestionSet?

    var type: QuestionType {
        get { QuestionType(rawValue: typeRaw) ?? .flashcard }
        set { typeRaw = newValue.rawValue }
    }

    /// 플래시카드의 뒷면 (= 첫 번째 정답).
    var flashcardBack: String { acceptedAnswers.first ?? "" }

    /// 이 문제를 실제로 풀 수 있는 상태인지.
    ///
    /// 출제 도중 저장된 미완성 카드가 세션에 섞여 들어가는 것을 막는다.
    var isAnswerable: Bool {
        guard !prompt.trimmed.isEmpty else { return false }
        switch type {
        case .multipleChoice:
            return choices.count >= 2
        case .flashcard, .fillInBlank, .shortAnswer:
            return !acceptedAnswers.isEmpty
        }
    }

    init(
        type: QuestionType = .flashcard,
        orderIndex: Int = 0,
        prompt: String = "",
        questionSet: QuestionSet? = nil
    ) {
        self.typeRaw = type.rawValue
        self.orderIndex = orderIndex
        self.prompt = prompt
        self.questionSet = questionSet
    }
}
