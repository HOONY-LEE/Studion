import Foundation

/// 문제 카드의 유형.
///
/// 명세: `docs/08-question-bank.md` §4
enum QuestionType: String, Codable, CaseIterable, Identifiable {
    /// 앞면을 보고 떠올린 뒤 뒤집어 확인한다. 앱이 채점하지 않는다.
    case flashcard
    /// 선택지 중 하나를 고른다.
    case multipleChoice
    /// 문장 속 빈칸(`____`)을 채운다.
    case fillInBlank
    /// 자유 입력으로 답한다.
    case shortAnswer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flashcard: String(localized: "카드")
        case .multipleChoice: String(localized: "객관식")
        case .fillInBlank: String(localized: "빈칸 채우기")
        case .shortAnswer: String(localized: "단답형")
        }
    }

    var systemImage: String {
        switch self {
        case .flashcard: "rectangle.on.rectangle"
        case .multipleChoice: "list.bullet.circle"
        case .fillInBlank: "square.dashed"
        case .shortAnswer: "pencil.line"
        }
    }

    /// 출제 화면에서 선택지를 입력받아야 하는 타입.
    var usesChoices: Bool { self == .multipleChoice }

    /// 출제 화면에서 정답 텍스트를 입력받아야 하는 타입.
    var usesTextAnswer: Bool { self != .multipleChoice }

    /// 앱이 채점할 수 있는 타입. 플래시카드는 학생이 스스로 판단한다.
    var isAutoGradable: Bool { self != .flashcard }
}
