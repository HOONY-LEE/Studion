#if DEBUG
import Foundation
import SwiftData

/// 개발 중 화면을 확인하기 위한 샘플 문제집.
///
/// **DEBUG 빌드에만 포함된다.** 출시본에는 이 파일 전체가 컴파일되지 않는다.
///
/// - Important: 여기 담긴 문제는 **전부 직접 작성한 것**이다. 시중 교재·기출문제 원문을
///   넣지 않는다 (→ `docs/00-product-principles.md` 원칙 5).
enum SampleDataSeeder {

    /// 샘플로 만든 문제집임을 표시하는 꼬리표. 삭제할 때 이걸로 골라낸다.
    static let sampleMarker = "샘플"

    // MARK: - 생성

    /// 4개 문제 타입과 부가 요소(보기 지문·해설·힌트·정답 미지정)를 모두 덮는 문제집을 만든다.
    static func seedQuestionSets(into context: ModelContext) {
        for blueprint in blueprints {
            let set = QuestionSet(
                title: blueprint.title,
                setDescription: blueprint.description,
                subjectName: blueprint.subject
            )
            set.authorDisplayName = sampleMarker
            context.insert(set)

            for (index, question) in blueprint.questions.enumerated() {
                let model = Question(
                    type: question.type,
                    orderIndex: index,
                    prompt: question.prompt,
                    questionSet: set
                )
                model.passageText = question.passage
                model.choices = question.choices
                model.correctChoiceIndex = question.correctChoiceIndex
                model.acceptedAnswers = question.acceptedAnswers
                model.explanation = question.explanation
                model.hint = question.hint
                context.insert(model)
            }

            set.touch()
        }
    }

    /// 샘플로 만든 문제집만 지운다. 사용자가 직접 만든 문제집은 건드리지 않는다.
    static func removeSampleQuestionSets(from context: ModelContext) {
        let descriptor = FetchDescriptor<QuestionSet>()
        guard let sets = try? context.fetch(descriptor) else { return }

        for set in sets where set.authorDisplayName == sampleMarker {
            context.delete(set)
        }
    }

    /// 현재 저장된 샘플 문제집 수.
    static func sampleQuestionSetCount(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<QuestionSet>()
        let sets = (try? context.fetch(descriptor)) ?? []
        return sets.filter { $0.authorDisplayName == sampleMarker }.count
    }

    // MARK: - 청사진

    private struct QuestionBlueprint {
        let type: QuestionType
        let prompt: String
        var passage: String = ""
        var choices: [String] = []
        var correctChoiceIndex: Int?
        var acceptedAnswers: [String] = []
        var explanation: String = ""
        var hint: String = ""
    }

    private struct SetBlueprint {
        let title: String
        let description: String
        let subject: String
        let questions: [QuestionBlueprint]
    }

    private static var blueprints: [SetBlueprint] {
        [englishVocabulary, mathCalculus, englishGrammar, koreanHistory, scienceMixed]
    }

    /// 카드 타입만 모은 세트. 듀오링고식 뜻 맞추기 흐름을 확인한다.
    private static let englishVocabulary = SetBlueprint(
        title: "영단어 Day 1",
        description: "자주 쓰이는 기초 단어 모음",
        subject: "영어",
        questions: [
            QuestionBlueprint(
                type: .flashcard,
                prompt: "abundant",
                acceptedAnswers: ["풍부한", "많은"],
                explanation: "abundance(풍부함)의 형용사형입니다.",
                hint: "a- 로 시작하는 '넉넉하다'는 뜻"
            ),
            QuestionBlueprint(
                type: .flashcard,
                prompt: "reluctant",
                acceptedAnswers: ["꺼리는", "마지못한"],
                explanation: "be reluctant to + 동사원형 = ~하기를 꺼리다"
            ),
            QuestionBlueprint(
                type: .flashcard,
                prompt: "inevitable",
                acceptedAnswers: ["피할 수 없는", "불가피한"],
                hint: "in(부정) + evitable(피할 수 있는)"
            ),
            QuestionBlueprint(
                type: .flashcard,
                prompt: "diligent",
                acceptedAnswers: ["부지런한", "성실한"]
            ),
            QuestionBlueprint(
                type: .flashcard,
                prompt: "ambiguous",
                acceptedAnswers: ["모호한", "애매한"],
                explanation: "뜻이 둘 이상으로 읽힐 때 씁니다."
            ),
        ]
    )

    /// 객관식 + 단답형. 해설과 힌트가 함께 나오는 경로를 확인한다.
    private static let mathCalculus = SetBlueprint(
        title: "미적분 기초 점검",
        description: "미분 개념을 짚고 넘어가는 문제",
        subject: "수학",
        questions: [
            QuestionBlueprint(
                type: .multipleChoice,
                prompt: "함수 f(x) = x²의 도함수는?",
                choices: ["x", "2x", "x²", "2x²"],
                correctChoiceIndex: 1,
                explanation: "xⁿ을 미분하면 n·xⁿ⁻¹ 입니다. 따라서 x²의 도함수는 2x입니다.",
                hint: "지수를 앞으로 내리고 지수에서 1을 뺍니다."
            ),
            QuestionBlueprint(
                type: .multipleChoice,
                prompt: "다음 중 상수함수의 도함수로 옳은 것은?",
                choices: ["1", "0", "x", "정의되지 않는다"],
                correctChoiceIndex: 1,
                explanation: "상수는 변하지 않으므로 변화율이 0입니다."
            ),
            QuestionBlueprint(
                type: .shortAnswer,
                prompt: "f(x) = 3x + 5 일 때 f(2)의 값은?",
                acceptedAnswers: ["11"],
                explanation: "3 × 2 + 5 = 11"
            ),
            QuestionBlueprint(
                type: .shortAnswer,
                prompt: "미분계수가 0이 되는 점을 무엇이라 부르나요?",
                acceptedAnswers: ["임계점", "critical point"],
                explanation: "극대·극소가 될 수 있는 후보 지점입니다.",
                hint: "극값의 후보가 되는 점"
            ),
            // 정답을 지정하지 않은 문제 — 채점 없이 골라보기만 하는 경로 확인용
            QuestionBlueprint(
                type: .multipleChoice,
                prompt: "미분을 배우면서 가장 헷갈렸던 개념은?",
                choices: ["극한의 정의", "연속과 미분가능", "합성함수 미분", "음함수 미분"],
                explanation: "정답이 없는 문제입니다. 스스로 점검해 보세요."
            ),
        ]
    )

    /// 빈칸 채우기 위주. `____` 표기가 화면에서 어떻게 보이는지 확인한다.
    private static let englishGrammar = SetBlueprint(
        title: "영문법 — 시제와 태",
        description: "빈칸을 채우며 문장 구조를 익힙니다",
        subject: "영어",
        questions: [
            QuestionBlueprint(
                type: .fillInBlank,
                prompt: "She ____ to school every morning.",
                acceptedAnswers: ["goes"],
                explanation: "주어가 3인칭 단수이고 반복되는 일이므로 현재시제 goes를 씁니다.",
                hint: "every morning — 반복되는 습관"
            ),
            QuestionBlueprint(
                type: .fillInBlank,
                prompt: "The window ____ broken by the storm last night.",
                acceptedAnswers: ["was"],
                explanation: "수동태 과거형입니다. 주어가 단수이므로 was를 씁니다."
            ),
            QuestionBlueprint(
                type: .fillInBlank,
                prompt: "I have ____ finished my homework.",
                acceptedAnswers: ["already"],
                explanation: "현재완료와 함께 '이미'를 뜻하는 already가 자주 쓰입니다."
            ),
            QuestionBlueprint(
                type: .multipleChoice,
                prompt: "다음 중 현재완료 시제가 쓰인 문장은?",
                choices: [
                    "I went to Busan last year.",
                    "I have been to Busan twice.",
                    "I will go to Busan.",
                    "I am going to Busan.",
                ],
                correctChoiceIndex: 1,
                explanation: "have/has + 과거분사 형태가 현재완료입니다."
            ),
        ]
    )

    /// 보기 지문이 딸린 문제. 긴 지문이 화면에서 어떻게 접히는지 확인한다.
    private static let koreanHistory = SetBlueprint(
        title: "한국사 흐름 잡기",
        description: "지문을 읽고 답하는 연습",
        subject: "한국사",
        questions: [
            QuestionBlueprint(
                type: .multipleChoice,
                prompt: "윗글에서 설명하는 제도의 이름은?",
                passage: """
                    이 제도는 신라에서 골품에 따라 관직의 상한과 일상생활의 규모까지 \
                    제한하던 신분 제도였다. 집의 크기, 수레의 장식, 옷의 색깔까지 \
                    신분에 따라 달리 정해졌다.
                    """,
                choices: ["골품제", "과거제", "음서제", "노비안검법"],
                correctChoiceIndex: 0,
                explanation: "골품제는 신라의 폐쇄적 신분 제도로, 6두품은 아무리 능력이 뛰어나도 오를 수 있는 관직에 한계가 있었습니다."
            ),
            QuestionBlueprint(
                type: .shortAnswer,
                prompt: "윗글의 밑줄 친 왕이 세운 나라의 이름을 쓰시오.",
                passage: """
                    그는 고구려 유민을 이끌고 동모산 기슭에 도읍을 정했다. \
                    이후 이 나라는 스스로를 고구려를 잇는 나라로 여겼고, \
                    일본에 보낸 문서에서도 그렇게 밝혔다.
                    """,
                acceptedAnswers: ["발해"],
                explanation: "대조영이 세운 발해입니다. 고구려 계승 의식을 여러 기록에서 확인할 수 있습니다.",
                hint: "해동성국이라 불린 나라"
            ),
            QuestionBlueprint(
                type: .multipleChoice,
                prompt: "조선 세종 대에 만들어진 것으로 옳지 않은 것은?",
                choices: ["훈민정음", "측우기", "앙부일구", "대동여지도"],
                correctChoiceIndex: 3,
                explanation: "대동여지도는 조선 후기 김정호가 만들었습니다. 나머지는 세종 대의 성과입니다."
            ),
        ]
    )

    /// 네 타입을 한 세트에 섞었다. 세션이 타입을 오가며 잘 전환되는지 확인한다.
    private static let scienceMixed = SetBlueprint(
        title: "과학 — 타입 섞어보기",
        description: "네 가지 문제 유형이 모두 들어 있습니다",
        subject: "통합과학",
        questions: [
            QuestionBlueprint(
                type: .flashcard,
                prompt: "광합성",
                acceptedAnswers: ["빛 에너지를 이용해 이산화탄소와 물로 포도당을 만드는 과정"],
                explanation: "엽록체에서 일어나며 산소가 부산물로 나옵니다."
            ),
            QuestionBlueprint(
                type: .multipleChoice,
                prompt: "물의 화학식으로 옳은 것은?",
                choices: ["H₂O", "CO₂", "O₂", "NaCl"],
                correctChoiceIndex: 0,
                explanation: "수소 원자 2개와 산소 원자 1개가 결합한 분자입니다."
            ),
            QuestionBlueprint(
                type: .fillInBlank,
                prompt: "물질이 고체에서 액체로 변하는 현상을 ____ 이라고 한다.",
                acceptedAnswers: ["융해"],
                explanation: "반대로 액체에서 고체로 변하는 것은 응고입니다.",
                hint: "얼음이 녹는 것"
            ),
            QuestionBlueprint(
                type: .shortAnswer,
                prompt: "지구에서 가장 많은 비율을 차지하는 대기 성분은?",
                acceptedAnswers: ["질소", "N2", "N₂"],
                explanation: "약 78%가 질소이고 산소는 약 21%입니다."
            ),
        ]
    )
}
#endif
