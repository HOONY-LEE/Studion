import SwiftUI

/// 시간표 블록 하나.
///
/// 색은 **과목**을 나타낸다 (→ `TimetableColorAssigner`). 학교/학원 구분은 색이 아니라
/// 아이콘과 텍스트 레이블이 맡는다 — 원래도 색만으로 구분하지 않는 원칙이었고,
/// 색을 과목에 내주면서 그 원칙이 오히려 더 잘 지켜진다.
struct TimetableBlockView: View {
    /// 좌측 강조 바 두께. 글자 크기에 따라 함께 커지도록 스케일한다.
    @ScaledMetric(relativeTo: .footnote) private var accentBarWidth: CGFloat = 3

    let title: String
    /// 이동수업 교실. 비어 있으면 표시하지 않는다.
    var location: String = ""
    let type: TimetableEntryType
    /// 과목 색 번호. 같은 과목이면 어느 요일이든 같은 번호가 온다.
    var colorIndex: Int = 0
    let startTime: Date
    let endTime: Date
    /// 좁은 폭에서는 시간 표시를 생략한다.
    var isCompact: Bool = false

    private var tint: Color { TimetableColorPalette.color(at: colorIndex) }

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

            // 이동수업은 "어느 교실인지"가 과목명만큼 중요하다. 좁은 칸에서도 한 줄은 남긴다.
            if !location.trimmed.isEmpty {
                Text(verbatim: location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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
        .accessibilityLabel(
            location.trimmed.isEmpty
                ? "\(typeLabel) 일정, \(title), \(timeRangeText)"
                : "\(typeLabel) 일정, \(title), \(location), \(timeRangeText)"
        )
    }
}

#Preview {
    let start = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    let end = Calendar.current.date(from: DateComponents(hour: 10, minute: 30))!
    return VStack(spacing: 8) {
        TimetableBlockView(title: "국어", type: .school, colorIndex: 0, startTime: start, endTime: end)
        TimetableBlockView(title: "물리학", location: "과학실", type: .school, colorIndex: 2, startTime: start, endTime: end)
        TimetableBlockView(title: "수학 학원", type: .academy, colorIndex: 4, startTime: start, endTime: end)
    }
    .padding()
}
