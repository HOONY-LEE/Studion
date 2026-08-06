import Foundation
import SwiftData

/// SwiftData ↔ 백업 DTO 변환.
enum BackupService {

    enum RestoreMode {
        /// 기존 데이터를 지우고 백업으로 교체한다.
        case replace
        /// 기존 데이터를 두고 백업 내용을 추가한다.
        case merge
    }

    // MARK: - 내보내기

    static func makeDocument(from context: ModelContext, exportedAt: Date) throws -> BackupDocument {
        let profile = try context.fetch(FetchDescriptor<AcademicProfile>()).first
        let semesters = try context.fetch(FetchDescriptor<Semester>())
        let sessions = try context.fetch(FetchDescriptor<MockExamSession>())
        let entries = try context.fetch(FetchDescriptor<TimetableEntry>())
        let planItems = try context.fetch(FetchDescriptor<PlanItem>())

        return BackupDocument(
            exportedAt: exportedAt,
            academicProfile: profile.map {
                .init(
                    admissionYear: $0.admissionYear,
                    gradeLevel: $0.gradeLevel,
                    gradingSystemType: $0.gradingSystemTypeRaw
                )
            },
            semesters: semesters.map { semester in
                .init(
                    year: semester.year,
                    term: semester.term,
                    gradingSystemType: semester.gradingSystemTypeRaw,
                    createdAt: semester.createdAt,
                    subjectRecords: (semester.subjectRecords ?? []).map(makeSchoolSubjectDTO)
                )
            },
            mockExamSessions: sessions.map { session in
                .init(
                    name: session.name,
                    examDate: session.examDate,
                    createdAt: session.createdAt,
                    subjectRecords: (session.subjectRecords ?? []).map(makeMockExamSubjectDTO)
                )
            },
            timetableEntries: entries.map {
                .init(
                    dayOfWeek: $0.dayOfWeek,
                    startTime: $0.startTime,
                    endTime: $0.endTime,
                    title: $0.title,
                    location: $0.location,
                    colorIndex: $0.colorIndex,
                    type: $0.typeRaw,
                    repeatsWeekly: $0.repeatsWeekly,
                    createdAt: $0.createdAt
                )
            },
            planItems: planItems.map {
                .init(
                    title: $0.title,
                    date: $0.date,
                    isDone: $0.isDone,
                    relatedSubjectName: $0.relatedSubjectName,
                    createdAt: $0.createdAt
                )
            }
        )
    }

    private static func makeSchoolSubjectDTO(
        _ record: SchoolSubjectRecord
    ) -> BackupDocument.SchoolSubjectDTO {
        .init(
            subjectName: record.subjectName,
            creditUnits: record.creditUnits,
            rawScore: record.rawScore,
            subjectAverage: record.subjectAverage,
            stdDeviation: record.stdDeviation,
            studentCount: record.studentCount,
            evaluationType: record.evaluationTypeRaw,
            achievementLevel: record.achievementLevelRaw,
            rankGrade: record.rankGrade,
            targetGrade: record.targetGrade,
            createdAt: record.createdAt,
            wrongAnswerNotes: (record.wrongAnswerNotes ?? []).map(makeNoteDTO)
        )
    }

    private static func makeMockExamSubjectDTO(
        _ record: MockExamSubjectRecord
    ) -> BackupDocument.MockExamSubjectDTO {
        .init(
            subjectName: record.subjectName,
            rawScore: record.rawScore,
            standardScore: record.standardScore,
            percentile: record.percentile,
            grade: record.grade,
            createdAt: record.createdAt,
            wrongAnswerNotes: (record.wrongAnswerNotes ?? []).map(makeNoteDTO)
        )
    }

    private static func makeNoteDTO(_ note: WrongAnswerNote) -> BackupDocument.WrongAnswerNoteDTO {
        .init(
            ocrRawText: note.ocrRawText,
            userEditedText: note.userEditedText,
            causeTag: note.causeTagRaw,
            englishSubcategory: note.englishSubcategoryRaw,
            createdAt: note.createdAt,
            leitnerBoxIndex: note.leitnerBoxIndex,
            nextReviewDate: note.nextReviewDate,
            lastReviewedAt: note.lastReviewedAt,
            passageText: note.passageText,
            promptText: note.promptText,
            choices: note.choices,
            explanation: note.explanation,
            isMultipleChoice: note.isMultipleChoice,
            correctChoiceIndex: note.correctChoiceIndex
        )
    }

    // MARK: - 복원

    /// 백업을 복원한다.
    ///
    /// **검증을 먼저 전부 수행한 뒤에 쓰기를 시작한다.** 중간에 실패해 부분 적용된 상태로
    /// 남지 않게 하기 위함이다.
    static func restore(
        _ document: BackupDocument,
        mode: RestoreMode,
        into context: ModelContext
    ) throws {
        try document.validate()

        if mode == .replace {
            try deleteAll(in: context)
        }

        if let profile = document.academicProfile {
            let model = AcademicProfile(
                admissionYear: profile.admissionYear,
                gradeLevel: profile.gradeLevel,
                gradingSystemType: GradingSystemType(rawValue: profile.gradingSystemType) ?? .fiveTier
            )
            context.insert(model)
        }

        for dto in document.semesters {
            let semester = Semester(
                year: dto.year,
                term: dto.term,
                gradingSystemType: GradingSystemType(rawValue: dto.gradingSystemType) ?? .fiveTier
            )
            semester.createdAt = dto.createdAt
            context.insert(semester)

            for subjectDTO in dto.subjectRecords {
                let record = SchoolSubjectRecord(semester: semester)
                record.subjectName = subjectDTO.subjectName
                record.creditUnits = subjectDTO.creditUnits
                record.rawScore = subjectDTO.rawScore
                record.subjectAverage = subjectDTO.subjectAverage
                record.stdDeviation = subjectDTO.stdDeviation
                record.studentCount = subjectDTO.studentCount
                record.evaluationTypeRaw = subjectDTO.evaluationType
                record.achievementLevelRaw = subjectDTO.achievementLevel
                record.rankGrade = subjectDTO.rankGrade
                record.targetGrade = subjectDTO.targetGrade
                record.createdAt = subjectDTO.createdAt
                context.insert(record)

                for noteDTO in subjectDTO.wrongAnswerNotes {
                    let note = makeNote(from: noteDTO)
                    note.schoolSubject = record
                    context.insert(note)
                }
            }
        }

        for dto in document.mockExamSessions {
            let session = MockExamSession(name: dto.name, examDate: dto.examDate)
            session.createdAt = dto.createdAt
            context.insert(session)

            for subjectDTO in dto.subjectRecords {
                let record = MockExamSubjectRecord(session: session)
                record.subjectName = subjectDTO.subjectName
                record.rawScore = subjectDTO.rawScore
                record.standardScore = subjectDTO.standardScore
                record.percentile = subjectDTO.percentile
                record.grade = subjectDTO.grade
                record.createdAt = subjectDTO.createdAt
                context.insert(record)

                for noteDTO in subjectDTO.wrongAnswerNotes {
                    let note = makeNote(from: noteDTO)
                    note.mockExamSubject = record
                    context.insert(note)
                }
            }
        }

        for dto in document.timetableEntries {
            let entry = TimetableEntry(
                dayOfWeek: dto.dayOfWeek,
                startTime: dto.startTime,
                endTime: dto.endTime,
                title: dto.title,
                location: dto.location ?? "",
                type: TimetableEntryType(rawValue: dto.type) ?? .school,
                colorIndex: dto.colorIndex ?? 0,
                repeatsWeekly: dto.repeatsWeekly
            )
            entry.createdAt = dto.createdAt
            context.insert(entry)
        }

        for dto in document.planItems {
            let item = PlanItem(title: dto.title, date: dto.date)
            item.isDone = dto.isDone
            item.relatedSubjectName = dto.relatedSubjectName
            item.createdAt = dto.createdAt
            context.insert(item)
        }

        try context.save()
    }

    private static func makeNote(from dto: BackupDocument.WrongAnswerNoteDTO) -> WrongAnswerNote {
        let note = WrongAnswerNote()
        note.ocrRawText = dto.ocrRawText
        note.userEditedText = dto.userEditedText
        note.causeTagRaw = dto.causeTag
        note.englishSubcategoryRaw = dto.englishSubcategory
        note.createdAt = dto.createdAt
        note.leitnerBoxIndex = dto.leitnerBoxIndex
        note.nextReviewDate = dto.nextReviewDate
        note.lastReviewedAt = dto.lastReviewedAt
        note.passageText = dto.passageText ?? ""
        note.promptText = dto.promptText ?? ""
        note.choices = dto.choices ?? []
        note.explanation = dto.explanation ?? ""
        // 옛 백업에는 이 값이 없다. 비워두면 `content`가 `userEditedText`에서 다시 나눠 읽는다.
        note.isMultipleChoice = dto.isMultipleChoice ?? false
        note.correctChoiceIndex = dto.correctChoiceIndex
        return note
    }

    private static func deleteAll(in context: ModelContext) throws {
        // 관계가 cascade이므로 최상위 엔티티만 지우면 하위도 함께 사라진다.
        try context.delete(model: Semester.self)
        try context.delete(model: MockExamSession.self)
        try context.delete(model: TimetableEntry.self)
        try context.delete(model: PlanItem.self)
        try context.delete(model: AcademicProfile.self)
        // 어느 과목에도 연결되지 않은 오답노트가 남을 수 있으므로 별도로 정리한다.
        try context.delete(model: WrongAnswerNote.self)
    }
}
