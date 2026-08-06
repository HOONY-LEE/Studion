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
    /// 수업을 듣는 곳. 이동수업이면 그 반(예: "3-5", "과학실"), 아니면 비워 둔다.
    ///
    /// 이동수업은 "어느 교실로 가야 하나"가 과목명만큼 중요한데, 시간표를 보는 순간
    /// 그걸 알 수 없으면 결국 다른 데를 또 찾아봐야 한다.
    var location: String = ""
    var typeRaw: String = TimetableEntryType.school.rawValue
    /// 시간표 칸 색 (→ `TimetableColorPalette`). 과목마다 다른 색을 주기 위한 것이라
    /// **같은 과목끼리는 같은 번호**여야 한다 (→ `TimetableColorAssigner`).
    var colorIndex: Int = 0
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
        location: String = "",
        type: TimetableEntryType = .school,
        colorIndex: Int = 0,
        repeatsWeekly: Bool = true
    ) {
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.location = location
        self.typeRaw = type.rawValue
        self.colorIndex = colorIndex
        self.repeatsWeekly = repeatsWeekly
    }
}
