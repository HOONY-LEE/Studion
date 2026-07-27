import Foundation
import SwiftData

/// 학교/학원 시간표 한 칸. startTime/endTime은 시각(시:분)만 의미가 있다.
@Model
final class TimetableEntry {
    /// 요일. Calendar 컨벤션과 동일하게 1=일요일 ... 7=토요일.
    var dayOfWeek: Int = 2
    var startTime: Date = Date()
    var endTime: Date = Date()
    var title: String = ""
    var typeRaw: String = TimetableEntryType.school.rawValue
    var repeatsWeekly: Bool = true
    var createdAt: Date = Date()

    var type: TimetableEntryType {
        get { TimetableEntryType(rawValue: typeRaw) ?? .school }
        set { typeRaw = newValue.rawValue }
    }

    init(
        dayOfWeek: Int = 2,
        startTime: Date = Date(),
        endTime: Date = Date(),
        title: String = "",
        type: TimetableEntryType = .school,
        repeatsWeekly: Bool = true
    ) {
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.typeRaw = type.rawValue
        self.repeatsWeekly = repeatsWeekly
    }
}
