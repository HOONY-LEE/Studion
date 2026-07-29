#if DEBUG
import Foundation
import Testing
import SwiftData
@testable import Studion

/// 샘플 데이터가 실제로 저장되고, 학습 세션이 쓸 수 있는 상태인지 확인한다.
@Suite("샘플 문제집 시드")
@MainActor
struct SampleDataSeederTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            AcademicProfile.self, Semester.self, SchoolSubjectRecord.self,
            MockExamSession.self, MockExamSubjectRecord.self, WrongAnswerNote.self,
            TimetableEntry.self, PlanItem.self, QuestionSet.self, Question.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }

    private func fetchSets(_ context: ModelContext) throws -> [QuestionSet] {
        try context.fetch(FetchDescriptor<QuestionSet>())
    }

    @Test("문제집이 여러 개 만들어진다")
    func seedsMultipleSets() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        let sets = try fetchSets(context)
        #expect(sets.count >= 4)
        #expect(sets.allSatisfy { !$0.title.trimmed.isEmpty })
    }

    @Test("각 문제집에 문제가 들어 있다")
    func everySetHasQuestions() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        for set in try fetchSets(context) {
            #expect(set.questionCount >= 3, "\(set.title)에 문제가 부족합니다")
        }
    }

    @Test("네 가지 문제 유형이 모두 등장한다")
    func coversAllQuestionTypes() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        let allQuestions = try fetchSets(context).flatMap { $0.sortedQuestions }
        let types = Set(allQuestions.map(\.type))

        for type in QuestionType.allCases {
            #expect(types.contains(type), "\(type.displayName) 유형이 없습니다")
        }
    }

    @Test("모든 문제가 풀 수 있는 상태다 — 미완성 카드가 섞이지 않는다")
    func everyQuestionIsAnswerable() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        for set in try fetchSets(context) {
            for question in set.sortedQuestions {
                #expect(question.isAnswerable, "'\(question.prompt)'를 풀 수 없습니다")
            }
        }
    }

    @Test("객관식 정답 인덱스가 선택지 범위 안에 있다")
    func correctIndexIsInRange() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        let multipleChoice = try fetchSets(context)
            .flatMap { $0.sortedQuestions }
            .filter { $0.type == .multipleChoice }

        #expect(!multipleChoice.isEmpty)
        for question in multipleChoice {
            #expect(question.choices.count >= 2)
            #expect(question.choices.count <= 5)
            if let index = question.correctChoiceIndex {
                #expect(question.choices.indices.contains(index), "'\(question.prompt)'의 정답 인덱스가 범위 밖입니다")
            }
        }
    }

    @Test("정답을 지정하지 않은 문제도 포함된다 — 채점 없는 경로 확인용")
    func includesUngradedQuestion() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        let ungraded = try fetchSets(context)
            .flatMap { $0.sortedQuestions }
            .filter { $0.type == .multipleChoice && $0.correctChoiceIndex == nil }

        #expect(!ungraded.isEmpty)
    }

    @Test("빈칸 문제에는 빈칸 표기가 들어 있다")
    func fillInBlankHasMarker() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        let blanks = try fetchSets(context)
            .flatMap { $0.sortedQuestions }
            .filter { $0.type == .fillInBlank }

        #expect(!blanks.isEmpty)
        for question in blanks {
            #expect(
                QuestionGrader.containsBlank(question.prompt),
                "'\(question.prompt)'에 빈칸 표기(____)가 없습니다"
            )
        }
    }

    @Test("보기 지문이 있는 문제가 포함된다")
    func includesPassage() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        let withPassage = try fetchSets(context)
            .flatMap { $0.sortedQuestions }
            .filter { !$0.passageText.isEmpty }

        #expect(!withPassage.isEmpty)
    }

    @Test("orderIndex가 0부터 순서대로 매겨진다")
    func orderIndexIsSequential() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        for set in try fetchSets(context) {
            let indices = set.sortedQuestions.map(\.orderIndex)
            #expect(indices == Array(0..<indices.count), "\(set.title)의 순서가 어긋납니다")
        }
    }

    @Test("샘플 문제집만 골라 지운다 — 사용자 문제집은 남는다")
    func removesOnlySampleSets() throws {
        let context = try makeContext()

        let userSet = QuestionSet(title: "내가 만든 문제집")
        context.insert(userSet)
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        let beforeCount = try fetchSets(context).count
        #expect(beforeCount > 1)

        SampleDataSeeder.removeSampleQuestionSets(from: context)
        try context.save()

        let remaining = try fetchSets(context)
        #expect(remaining.count == 1)
        #expect(remaining.first?.title == "내가 만든 문제집")
    }

    @Test("삭제하면 하위 문제도 함께 사라진다")
    func deletingSetsCascades() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        #expect(try !context.fetch(FetchDescriptor<Question>()).isEmpty)

        SampleDataSeeder.removeSampleQuestionSets(from: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Question>()).isEmpty)
    }

    @Test("두 번 넣으면 두 배가 된다 — 중복 방지는 UI가 아니라 사용자 판단에 맡긴다")
    func seedingTwiceDuplicates() throws {
        let context = try makeContext()
        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()
        let first = try fetchSets(context).count

        SampleDataSeeder.seedQuestionSets(into: context)
        try context.save()

        #expect(try fetchSets(context).count == first * 2)
        #expect(SampleDataSeeder.sampleQuestionSetCount(in: context) == first * 2)
    }
}
#endif
