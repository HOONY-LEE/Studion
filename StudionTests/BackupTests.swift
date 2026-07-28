import Foundation
import Testing
import SwiftData
@testable import Studion

/// 백업은 데이터 손실과 직결되므로 왕복(내보내기 → 가져오기)이 값을 보존하는지 검증한다.
@Suite("백업 라운드트립")
@MainActor
struct BackupTests {

    /// 메모리 전용 컨테이너. 테스트가 실제 저장소를 건드리지 않게 한다.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            AcademicProfile.self, Semester.self, SchoolSubjectRecord.self,
            MockExamSession.self, MockExamSubjectRecord.self, WrongAnswerNote.self,
            TimetableEntry.self, PlanItem.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func seed(_ context: ModelContext) {
        let profile = AcademicProfile(admissionYear: 2025, gradeLevel: 2, gradingSystemType: .fiveTier)
        context.insert(profile)

        let semester = Semester(year: 2026, term: 1, gradingSystemType: .fiveTier)
        context.insert(semester)

        let subject = SchoolSubjectRecord(
            subjectName: "국어", creditUnits: 4, evaluationType: .achievementAndRank, semester: semester
        )
        subject.rawScore = 92
        subject.subjectAverage = 70
        subject.stdDeviation = 12
        subject.rankGrade = 2
        subject.targetGrade = 1
        context.insert(subject)

        let note = WrongAnswerNote(ocrRawText: "원본", userEditedText: "수정본", causeTag: .mistake)
        note.leitnerBoxIndex = 2
        note.schoolSubject = subject
        context.insert(note)

        let session = MockExamSession(name: "2026년 6월 학평", examDate: Date(timeIntervalSince1970: 1_780_000_000))
        context.insert(session)

        let mockSubject = MockExamSubjectRecord(subjectName: "수학", session: session)
        mockSubject.grade = 3
        mockSubject.percentile = 77
        context.insert(mockSubject)

        context.insert(TimetableEntry(dayOfWeek: 3, title: "물리", type: .academy))
        context.insert(PlanItem(title: "문제집 3장", date: Date(timeIntervalSince1970: 1_780_000_000)))
    }

    @Test("내보낸 뒤 다시 가져오면 값이 보존된다")
    func roundTripPreservesValues() throws {
        let source = try makeContext()
        seed(source)
        try source.save()

        let document = try BackupService.makeDocument(from: source, exportedAt: Date())
        let data = try BackupDocument.makeEncoder().encode(document)
        let decoded = try BackupDocument.makeDecoder().decode(BackupDocument.self, from: data)

        let target = try makeContext()
        try BackupService.restore(decoded, mode: .replace, into: target)

        let semesters = try target.fetch(FetchDescriptor<Semester>())
        #expect(semesters.count == 1)

        let subject = try #require(semesters.first?.subjectRecords?.first)
        #expect(subject.subjectName == "국어")
        #expect(subject.creditUnits == 4)
        #expect(subject.rankGrade == 2)
        #expect(subject.targetGrade == 1)
        #expect(subject.evaluationType == .achievementAndRank)

        let note = try #require(subject.wrongAnswerNotes?.first)
        #expect(note.ocrRawText == "원본")
        #expect(note.userEditedText == "수정본")
        #expect(note.causeTag == .mistake)
        #expect(note.leitnerBoxIndex == 2)

        let sessions = try target.fetch(FetchDescriptor<MockExamSession>())
        #expect(sessions.first?.name == "2026년 6월 학평")
        #expect(sessions.first?.subjectRecords?.first?.grade == 3)

        #expect(try target.fetch(FetchDescriptor<TimetableEntry>()).count == 1)
        #expect(try target.fetch(FetchDescriptor<PlanItem>()).count == 1)
    }

    @Test("덮어쓰기는 기존 데이터를 지운다")
    func replaceClearsExisting() throws {
        let source = try makeContext()
        seed(source)
        let document = try BackupService.makeDocument(from: source, exportedAt: Date())

        let target = try makeContext()
        target.insert(Semester(year: 2020, term: 2, gradingSystemType: .nineTier))
        try target.save()

        try BackupService.restore(document, mode: .replace, into: target)

        let semesters = try target.fetch(FetchDescriptor<Semester>())
        #expect(semesters.count == 1)
        #expect(semesters.first?.year == 2026)
    }

    @Test("병합은 기존 데이터를 유지한다")
    func mergeKeepsExisting() throws {
        let source = try makeContext()
        seed(source)
        let document = try BackupService.makeDocument(from: source, exportedAt: Date())

        let target = try makeContext()
        target.insert(Semester(year: 2020, term: 2, gradingSystemType: .nineTier))
        try target.save()

        try BackupService.restore(document, mode: .merge, into: target)

        #expect(try target.fetch(FetchDescriptor<Semester>()).count == 2)
    }

    @Test("더 새로운 스키마 버전은 거부한다 — 쓰기 전에 걸러진다")
    func rejectsNewerSchemaVersion() throws {
        var document = BackupDocument(
            exportedAt: Date(), academicProfile: nil, semesters: [],
            mockExamSessions: [], timetableEntries: [], planItems: []
        )
        document.schemaVersion = BackupDocument.currentSchemaVersion + 1

        #expect(throws: BackupDocument.ValidationError.self) {
            try document.validate()
        }
    }

    @Test("이미지는 백업에 포함하지 않는다")
    func imagesAreExcluded() throws {
        let source = try makeContext()
        seed(source)

        let subject = try #require(
            try source.fetch(FetchDescriptor<SchoolSubjectRecord>()).first
        )
        subject.wrongAnswerNotes?.first?.imageData = Data(repeating: 0xFF, count: 1024)
        try source.save()

        let document = try BackupService.makeDocument(from: source, exportedAt: Date())
        let data = try BackupDocument.makeEncoder().encode(document)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("imageData"))
    }
}
