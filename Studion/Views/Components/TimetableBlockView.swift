import SwiftUI

/// 시간표 블록 하나.
///
/// 학교/학원을 색상만으로 구분하지 않는다 — 아이콘과 텍스트 레이블을 함께 둔다.
struct TimetableBlockView: View {
    /// 좌측 강조 바 두께. 글자 크기에 따라 함께 커지도록 스케일한다.
    @ScaledMetric(relativeTo: .footnote) private var accentBarWidth: CGFloat = 3

    let title: String
    let type: TimetableEntryType
    let startTime: Date
    let endTime: Date
    /// 좁은 폭에서는 시간 표시를 생략한다.
    var isCompact: Bool = false

    private var tint: Color {
        switch type {
        case .school: Color("ScheduleSchool")
        case .academy: Color("ScheduleAcademy")
        }
    }

    private var iconName: String {
        switch type {
        case .school: "building.columns"
        case .academy: "book"
        }
    }

    private var typeLabel: String {
        switch type {
        case .school: String(localized: "학교")
        case .academy: String(localized: "학원")
        }
    }

    private var timeRangeText: String {
        let start = startTime.formatted(.dateTime.hour().minute())
        let end = endTime.formatted(.dateTime.hour().minute())
        return "\(start) – \(end)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text(typeLabel)
                    .font(.caption2)
                if !isCompact {
                    Spacer(minLength: 4)
                    Text(timeRangeText)
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(tint)

            Text(title)
                .font(.footnote.weight(.medium))
                .lineLimit(isCompact ? 1 : nil)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: accentBarWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(typeLabel) 일정, \(title), \(timeRangeText)")
    }
}

#Preview {
    let start = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    let end = Calendar.current.date(from: DateComponents(hour: 10, minute: 30))!
    return VStack(spacing: 8) {
        TimetableBlockView(title: "국어", type: .school, startTime: start, endTime: end)
        TimetableBlockView(title: "수학 학원", type: .academy, startTime: start, endTime: end)
    }
    .padding()
}
