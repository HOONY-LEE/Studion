import Foundation
import Testing
import SwiftData
@testable import Studion

/// 학기를 만들 때 공통과목이 실제로 저장되는지 확인한다.
///
/// 화면 코드가 `CurriculumPreset`을 어떻게 쓰는지를 그대로 재현해, 프리셋 데이터와
/// 저장 결과가 어긋나지 않는지 본다.
@Suite("학기 생성 시 공통과목 저장")
@MainActor
struct SemesterPresetIntegrationTests {

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

    /// `SemesterFormView.save()`가 하는 일을 그대로 옮긴 것이다.
    @discardableResult
    private func createSemester(
        in context: ModelContext,
        year: Int,
        term: Int,
        admissionYear: Int,
        includeCommonSubjects: Bool
    ) -> Semester {
        let revision = CurriculumRevision.forAdmissionYear(admissionYear)
        let semester = Semester(year: year, term: term, gradingSystemType: revision.gradingSystem)
        context.insert(semester)

        let isFirstYear = (year - admissionYear + 1) == 1
        if isFirstYear, includeCommonSubjects {
            for preset in CurriculumPreset.commonSubjects(for: revision, term: term) {
                context.insert(
                    SchoolSubjectRecord(
                        subjectName: preset.name,
                        creditUnits: preset.creditUnits,
                        evaluationType: preset.evaluationType,
                        semester: semester
                    )
                )
            }
        }
        return semester
    }

    @Test("2025년 입학 고1 1학기를 만들면 2022 개정 공통과목 7개가 들어간다")
    func createsCommonSubjectsFor2022() throws {
        let context = try makeContext()
        let semester = createSemester(
            in: context, year: 2025, term: 1, admissionYear: 2025, includeCommonSubjects: true
        )
        try context.save()

        let records = semester.subjectRecords ?? []
        #expect(records.count == 7)
        #expect(semester.gradingSystemType == .fiveTier)

        let names = Set(records.map(\.subjectName))
        #expect(names.contains("공통국어1"))
        #expect(names.contains("과학탐구실험1"))
    }

    @Test("과학탐구실험은 성취도만 기재로 저장된다")
    func scienceLabIsAchievementOnly() throws {
        let context = try makeContext()
        let semester = createSemester(
            in: context, year: 2025, term: 1, admissionYear: 2025, includeCommonSubjects: true
        )
        try context.save()

        let lab = (semester.subjectRecords ?? []).first { $0.subjectName.hasPrefix("과학탐구실험") }
        #expect(lab?.evaluationType == .achievementOnly)

        let others = (semester.subjectRecords ?? []).filter { !$0.subjectName.hasPrefix("과학탐구실험") }
        #expect(others.allSatisfy { $0.evaluationType == .achievementAndRank })
    }

    @Test("2024년 이전 입학은 9등급제 + 2015 개정 과목이 들어간다")
    func createsCommonSubjectsFor2015() throws {
        let context = try makeContext()
        let semester = createSemester(
            in: context, year: 2024, term: 1, admissionYear: 2024, includeCommonSubjects: true
        )
        try context.save()

        #expect(semester.gradingSystemType == .nineTier)
        let names = Set((semester.subjectRecords ?? []).map(\.subjectName))
        #expect(names.contains("국어"))
        #expect(!names.contains("공통국어1"))
    }

    @Test("2학기를 만들면 2가 붙은 과목이 들어간다")
    func secondTermSubjects() throws {
        let context = try makeContext()
        let semester = createSemester(
            in: context, year: 2025, term: 2, admissionYear: 2025, includeCommonSubjects: true
        )
        try context.save()

        let names = Set((semester.subjectRecords ?? []).map(\.subjectName))
        #expect(names.contains("공통국어2"))
        #expect(!names.contains("공통국어1"))
    }

    @Test("고2 학기에는 공통과목이 들어가지 않는다")
    func secondYearHasNoCommonSubjects() throws {
        let context = try makeContext()
        let semester = createSemester(
            in: context, year: 2026, term: 1, admissionYear: 2025, includeCommonSubjects: true
        )
        try context.save()

        #expect((semester.subjectRecords ?? []).isEmpty)
    }

    @Test("토글을 끄면 과목이 들어가지 않는다")
    func optOutCreatesEmptySemester() throws {
        let context = try makeContext()
        let semester = createSemester(
            in: context, year: 2025, term: 1, admissionYear: 2025, includeCommonSubjects: false
        )
        try context.save()

        #expect((semester.subjectRecords ?? []).isEmpty)
    }

    @Test("프리셋으로 넣은 과목도 이름·단위·평가 방식을 고칠 수 있다")
    func presetSubjectsRemainEditable() throws {
        let context = try makeContext()
        let semester = createSemester(
            in: context, year: 2025, term: 1, admissionYear: 2025, includeCommonSubjects: true
        )
        try context.save()

        let record = try #require((semester.subjectRecords ?? []).first { $0.subjectName == "공통국어1" })
        record.subjectName = "국어 심화"
        record.creditUnits = 5
        record.evaluationType = .achievementOnly
        try context.save()

        #expect(record.subjectName == "국어 심화")
        #expect(record.creditUnits == 5)
        #expect(record.evaluationType == .achievementOnly)
    }

    @Test("프리셋 과목을 지울 수 있다")
    func presetSubjectsAreDeletable() throws {
        let context = try makeContext()
        let semester = createSemester(
            in: context, year: 2025, term: 1, admissionYear: 2025, includeCommonSubjects: true
        )
        try context.save()

        let record = try #require((semester.subjectRecords ?? []).first)
        context.delete(record)
        try context.save()

        #expect((semester.subjectRecords ?? []).count == 6)
    }
}
