import Foundation

/// JSON 백업 포맷.
///
/// SwiftData `@Model`을 직접 `Codable`로 만들지 않는다 — 모델을 고칠 때마다 백업 포맷이
/// 조용히 깨지기 때문이다. 별도 DTO로 옮겨 담아 포맷을 명시적으로 관리한다.
///
/// 이미지는 백업에 포함하지 않는다 (용량). 그 사실을 UI에 명시한다.
struct BackupDocument: Codable {

    /// 포맷 버전. 과거 백업을 읽을 수 있어야 하므로 반드시 유지한다.
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var exportedAt: Date
    var academicProfile: ProfileDTO?
    var semesters: [SemesterDTO]
    var mockExamSessions: [MockExamSessionDTO]
    var timetableEntries: [TimetableEntryDTO]
    var planItems: [PlanItemDTO]

    // MARK: - 엔티티별 DTO

    struct ProfileDTO: Codable {
        var admissionYear: Int
        var gradeLevel: Int
        var gradingSystemType: String
    }

    struct SemesterDTO: Codable {
        var year: Int
        var term: Int
        var gradingSystemType: String
        var createdAt: Date
        var subjectRecords: [SchoolSubjectDTO]
    }

    struct SchoolSubjectDTO: Codable {
        var subjectName: String
        var creditUnits: Double
        var rawScore: Double?
        var subjectAverage: Double?
        var stdDeviation: Double?
        var studentCount: Int?
        var evaluationType: String
        var achievementLevel: String?
        var rankGrade: Int?
        var targetGrade: Int?
        var createdAt: Date
        var wrongAnswerNotes: [WrongAnswerNoteDTO]
    }

    struct MockExamSessionDTO: Codable {
        var name: String
        var examDate: Date
        var createdAt: Date
        var subjectRecords: [MockExamSubjectDTO]
    }

    struct MockExamSubjectDTO: Codable {
        var subjectName: String
        var rawScore: Double?
        var standardScore: Double?
        var percentile: Double?
        var grade: Int?
        var createdAt: Date
        var wrongAnswerNotes: [WrongAnswerNoteDTO]
    }

    /// 이미지(`imageData`)는 의도적으로 제외한다.
    struct WrongAnswerNoteDTO: Codable {
        var ocrRawText: String
        var userEditedText: String
        var causeTag: String
        var englishSubcategory: String?
        var createdAt: Date
        var leitnerBoxIndex: Int
        var nextReviewDate: Date
        var lastReviewedAt: Date?
    }

    struct TimetableEntryDTO: Codable {
        var dayOfWeek: Int
        var startTime: Date
        var endTime: Date
        var title: String
        var type: String
        var repeatsWeekly: Bool
        var createdAt: Date
    }

    struct PlanItemDTO: Codable {
        var title: String
        var date: Date
        var isDone: Bool
        var relatedSubjectName: String?
        var createdAt: Date
    }
}

// MARK: - 검증

extension BackupDocument {
    enum ValidationError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                String(localized: "이 백업 파일은 더 새로운 버전(v\(version))에서 만들어졌습니다. 앱을 업데이트한 뒤 다시 시도해 주세요.")
            }
        }
    }

    /// 쓰기를 시작하기 **전에** 전부 검증한다. 부분 적용된 상태로 남지 않게 하기 위함이다.
    func validate() throws {
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw ValidationError.unsupportedVersion(schemaVersion)
        }
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
