import SwiftUI
import SwiftData

/// 시간표. 교시 × 요일 표에서 **빈 칸을 눌러 바로 채운다** (에브리타임과 같은 방식).
///
/// 목록으로 하나씩 추가하면 "화요일 3교시가 비었네"가 눈에 안 들어온다. 표로 두면 빈 칸이
/// 그대로 보이고, 그 칸을 누르면 요일과 시각이 이미 채워진 채로 입력 화면이 열린다.
///
/// 교시 시각은 `SchoolPeriodSchedule`의 기본값을 쓰되, 저장되는 것은 사용자가 확인한
/// 실제 시각이다 — 학교 일과가 다르면 시각을 고치면 되고 표는 겹치는 줄에 그려준다.
struct TimetableGridView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar

    @Query(sort: \TimetableEntry.startTime) private var entries: [TimetableEntry]

    /// 교시 시각은 사용자가 학교에 맞게 고친 일과표를 따른다 (→ `SchoolPeriodSchedule`).
    @AppStorage(PreferenceKey.periodSchedule) private var scheduleJSON = ""

    @State private var newEntrySlot: NewEntrySlot?
    @State private var entryToEdit: TimetableEntry?
    @State private var isEditingSchedule = false
    @State private var isImportingPhoto = false
    @State private var isConfirmingClearAll = false
    @State private var entryToDelete: TimetableEntry?

    /// 줄 하나의 높이. 글자를 키우면 함께 커진다.
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 62
    @ScaledMetric(relativeTo: .caption2) private var gutterWidth: CGFloat = 40

    private var schedule: SchoolPeriodSchedule { SchoolPeriodSchedule(json: scheduleJSON) }
    private var periods: [SchoolPeriod] { schedule.periods }

    /// 표에 세울 요일. 기본은 월~금이고, 주말에 일정이 있으면 그 요일까지 늘린다.
    ///
    /// 주말 칸을 늘 비워두면 평일 칸이 그만큼 좁아진다. 반대로 주말 일정을 감추면 사라진
    /// 것처럼 보인다 — 있을 때만 늘린다.
    private var displayIndices: [Int] {
        let weekdayCount = 5
        let extra = entries
            .map { PlannerDateHelper.displayIndex(forCalendarWeekday: $0.dayOfWeek) }
            .filter { $0 >= weekdayCount }
        return Array(0...max(weekdayCount - 1, extra.max() ?? 0))
    }

    /// 표의 어느 교시에도 걸리지 않는 일정 (저녁 학원, 보여주는 교시 뒤의 일정 등).
    private var offGridEntries: [TimetableEntry] {
        entries.filter { placement(for: $0) == nil }
            .sorted { minutes(of: $0.startTime) < minutes(of: $1.startTime) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                grid
                offGridSection
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .background(Color.plannerPageBackground.ignoresSafeArea())
        .navigationTitle("시간표")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("사진으로 넣기", systemImage: "text.viewfinder") {
                        isImportingPhoto = true
                    }
                    Button("교시 시각", systemImage: "clock") {
                        isEditingSchedule = true
                    }
                    if !entries.isEmpty {
                        Divider()
                        Button("시간표 전체 지우기", systemImage: "trash", role: .destructive) {
                            isConfirmingClearAll = true
                        }
                    }
                } label: {
                    Label("시간표 메뉴", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditingSchedule) {
            TimetablePeriodSettingsView()
        }
        .sheet(isPresented: $isImportingPhoto) {
            TimetableImportView()
        }
        .confirmationDialog(
            "시간표를 전부 지울까요?",
            isPresented: $isConfirmingClearAll,
            titleVisibility: .visible
        ) {
            Button("전부 지우기", role: .destructive) { clearAll() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("수업 \(entries.count)개가 모두 사라집니다. 되돌릴 수 없습니다.")
        }
        .confirmationDialog(
            "이 수업을 삭제할까요?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let entryToDelete { context.delete(entryToDelete) }
                entryToDelete = nil
            }
            Button("취소", role: .cancel) { entryToDelete = nil }
        } message: {
            Text(entryToDelete.map { "\($0.title) 수업이 시간표에서 사라집니다." } ?? "")
        }
        .sheet(item: $newEntrySlot) { slot in
            TimetableFormView(defaultWeekday: slot.weekday, defaultPeriodNumber: slot.periodNumber)
        }
        .sheet(item: $entryToEdit) { entry in
            TimetableFormView(editing: entry)
        }
    }

    /// 사진으로 다시 넣기 전에 기존 것을 비울 때 쓴다 — 안 지우면 같은 수업이 두 번 들어간다.
    private func clearAll() {
        for entry in entries { context.delete(entry) }
    }

    /// `confirmationDialog`는 Bool 바인딩만 받는데, 지울 대상도 함께 들고 있어야 한다.
    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } })
    }

    // MARK: - 표

    private var grid: some View {
        VStack(spacing: 0) {
            header
            HStack(alignment: .top, spacing: 0) {
                gutter
                ForEach(displayIndices, id: \.self) { index in
                    dayColumn(displayIndex: index)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutterWidth)
            ForEach(displayIndices, id: \.self) { index in
                Text(weekdayName(displayIndex: index))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { divider }
    }

    private var gutter: some View {
        VStack(spacing: 0) {
            ForEach(periods) { period in
                VStack(spacing: 1) {
                    Text("\(period.number)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                    Text(verbatim: timeLabel(period.startMinutes))
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                .frame(width: gutterWidth, height: rowHeight)
                .overlay(alignment: .bottom) {
                    if schedule.isBeforeLunch(period) { lunchMark }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(period.number)교시, \(timeLabel(period.startMinutes)) 시작")
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(width: 0.5)
        }
    }

    private func dayColumn(displayIndex index: Int) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(periods) { period in
                    Button {
                        newEntrySlot = NewEntrySlot(
                            weekday: PlannerDateHelper.calendarWeekday(forDisplayIndex: index),
                            periodNumber: period.number
                        )
                    } label: {
                        Color.clear
                            .frame(height: rowHeight)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) {
                                // 점심시간은 줄을 따로 만들지 않고 굵은 선으로만 나눈다 —
                                // 빈 줄을 넣으면 표만 길어지고 누를 것도 없다.
                                if schedule.isBeforeLunch(period) {
                                    lunchMark
                                } else {
                                    divider
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(weekdayName(displayIndex: index)) \(period.number)교시 비어 있음")
                    .accessibilityHint("두 번 탭하면 이 칸에 일정을 추가합니다")
                }
            }

            ForEach(blocks(displayIndex: index)) { block in
                Button {
                    entryToEdit = block.entry
                } label: {
                    TimetableBlockView(
                        title: block.entry.title,
                        location: block.entry.location,
                        type: block.entry.type,
                        colorIndex: block.entry.colorIndex,
                        startTime: block.entry.startTime,
                        endTime: block.entry.endTime,
                        isCompact: true
                    )
                    .frame(height: rowHeight * CGFloat(block.span) - 4, alignment: .top)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("편집", systemImage: "pencil") { entryToEdit = block.entry }
                    Button("삭제", systemImage: "trash", role: .destructive) {
                        entryToDelete = block.entry
                    }
                }
                .padding(.horizontal, 2)
                .offset(y: rowHeight * CGFloat(block.rowOffset) + 2)
            }
        }
        .frame(maxWidth: .infinity)
        // 마지막 요일 오른쪽에는 긋지 않는다 — 표 테두리와 겹쳐 두 줄로 보인다.
        .overlay(alignment: .trailing) {
            if index != displayIndices.last { columnSeparator }
        }
    }

    private var columnSeparator: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.25))
            .frame(width: 0.5)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.25))
            .frame(height: 0.5)
    }

    /// 점심시간 자리.
    private var lunchMark: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
    }

    // MARK: - 표 밖 일정

    @ViewBuilder
    private var offGridSection: some View {
        if !offGridEntries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("교시 밖 일정")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(offGridEntries) { entry in
                    Button {
                        entryToEdit = entry
                    } label: {
                        HStack(spacing: 8) {
                            TimetableBlockView(
                                title: entry.title,
                                location: entry.location,
                                type: entry.type,
                                colorIndex: entry.colorIndex,
                                startTime: entry.startTime,
                                endTime: entry.endTime
                            )
                            Text(weekdayName(displayIndex: PlannerDateHelper.displayIndex(forCalendarWeekday: entry.dayOfWeek)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("편집", systemImage: "pencil") { entryToEdit = entry }
                        Button("삭제", systemImage: "trash", role: .destructive) { entryToDelete = entry }
                    }
                }

                Text("표에 있는 교시 시간과 겹치지 않는 일정입니다. 학원처럼 일과 뒤 일정이 여기 모입니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 배치 계산

    /// 표 안에서 한 칸이 놓일 자리.
    private struct Block: Identifiable {
        let entry: TimetableEntry
        /// 맨 윗줄에서 몇 줄 아래인지.
        let rowOffset: Int
        /// 몇 줄을 차지하는지.
        let span: Int

        var id: PersistentIdentifier { entry.persistentModelID }
    }

    private func blocks(displayIndex index: Int) -> [Block] {
        entries
            .filter { PlannerDateHelper.displayIndex(forCalendarWeekday: $0.dayOfWeek) == index }
            .compactMap { entry in
                guard let placed = placement(for: entry) else { return nil }
                return Block(entry: entry, rowOffset: placed.rowOffset, span: placed.span)
            }
    }

    private func placement(for entry: TimetableEntry) -> (rowOffset: Int, span: Int)? {
        let covered = schedule.periods(
            overlapping: minutes(of: entry.startTime),
            end: minutes(of: entry.endTime)
        )
        guard let first = covered.first, let last = covered.last else { return nil }
        return (rowOffset: first.number - 1, span: last.number - first.number + 1)
    }

    private func minutes(of date: Date) -> Int {
        PlannerDateHelper.minutesOfDay(date, calendar: calendar)
    }

    private func timeLabel(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func weekdayName(displayIndex index: Int) -> String {
        let weekday = PlannerDateHelper.calendarWeekday(forDisplayIndex: index)
        return calendar.shortWeekdaySymbols[weekday - 1]
    }
}

/// 비어 있는 칸을 눌렀을 때 입력 화면에 넘길 자리.
private struct NewEntrySlot: Identifiable {
    let weekday: Int
    let periodNumber: Int

    var id: String { "\(weekday)-\(periodNumber)" }
}
