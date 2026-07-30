import SwiftUI
import SwiftData
import UIKit

/// 플래너의 "일간" — Gradin의 오늘 할 일 화면을 Studion 데이터에 맞춰 옮긴 것.
///
/// 카드 목록 하나로 그날의 시간표와 할 일을 이어서 보여주고, 좌우로 넘기면 날짜가 바뀐다.
/// 완료 개수와 진행 바는 **할 일만** 센다 — 시간표는 체크할 대상이 아니라 그날의 일과다
/// (Gradin은 시스템 캘린더 일정도 체크 대상으로 다루지만, Studion의 시간표는 매주 반복되는
/// 수업 시간이라 "완료"라는 개념이 맞지 않는다).
struct PlannerTodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date
    /// 상단 바의 + 가 눌렸다는 신호. 처리한 뒤 직접 끈다.
    @Binding var addRequested: Bool

    @Query private var allEntries: [TimetableEntry]
    @Query private var allPlanItems: [PlanItem]

    @State private var isEditMode = false
    @State private var inlineTitle = ""
    @State private var editingItem: PlanItem?
    @State private var scrolledDayIndex: Int?
    @FocusState private var isInlineFieldFocused: Bool

    private var today: Date { PlannerDateHelper.startOfDay(Date(), calendar: calendar) }

    // MARK: - 날짜별 항목

    private func entries(on date: Date) -> [TimetableEntry] {
        let weekday = PlannerDateHelper.calendarWeekday(of: date, calendar: calendar)
        return allEntries
            .filter { $0.dayOfWeek == weekday }
            .sorted {
                PlannerDateHelper.minutesOfDay($0.startTime, calendar: calendar)
                    < PlannerDateHelper.minutesOfDay($1.startTime, calendar: calendar)
            }
    }

    private func planItems(on date: Date) -> [PlanItem] {
        allPlanItems
            .filter { PlannerDateHelper.isSameDay($0.date, date, calendar: calendar) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func isEmpty(_ date: Date) -> Bool {
        entries(on: date).isEmpty && planItems(on: date).isEmpty
    }

    private var completedCount: Int {
        planItems(on: selectedDate).filter(\.isDone).count
    }

    private var totalCount: Int {
        planItems(on: selectedDate).count
    }

    private var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    // MARK: - 본문

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            progressBar
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            dayPager
        }
        .safeAreaInset(edge: .bottom) {
            if isEditMode {
                addRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $editingItem) { item in
            PlanItemFormView(editing: item)
        }
        .onChange(of: addRequested) { _, requested in
            guard requested else { return }
            addRequested = false
            withAnimation(.easeInOut(duration: 0.2)) { isEditMode = true }
            // 입력 줄이 올라오는 애니메이션이 끝난 뒤에 포커스를 준다 — 먼저 주면
            // 키보드가 올라오다 말고 위치가 어긋난다.
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                isInlineFieldFocused = true
            }
        }
        .onAppear {
            if scrolledDayIndex == nil {
                scrolledDayIndex = PlannerDateHelper.dayIndex(for: selectedDate, calendar: calendar)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Gradin과 같이 제목은 고정하고, 보고 있는 날짜를 옆에 작게 붙인다
            // (좌우로 넘기면 이 날짜만 바뀐다).
            Text("오늘 할 일")
                .font(.system(size: 28, weight: .bold))
            Text(verbatim: selectedDate.formatted(.dateTime.month().day()))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()

            // 추가는 상단 바의 + 가 맡는다. 여기에는 입력 중일 때 끝내는 버튼만 둔다.
            if isEditMode {
                Button {
                    isInlineFieldFocused = false
                    withAnimation(.easeInOut(duration: 0.2)) { isEditMode = false }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("추가 마치기")
            }
        }
    }

    /// 할 일 완료 비율. 목표 미달을 색으로 나무라지 않도록 채움만 accent로 두고
    /// 남은 부분은 중립 회색이다 (→ `docs/00-product-principles.md` 색채 원칙).
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemFill))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, geo.size.width * progress))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 6)
        // 바만으로는 무엇을 나타내는지 화면에서 읽히지 않으므로 음성 안내에는 남긴다.
        .accessibilityElement()
        .accessibilityLabel("할 일 \(totalCount)개 중 \(completedCount)개 완료")
    }

    // MARK: - 좌우 페이징

    private var dayPager: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(pageRange, id: \.self) { index in
                        page(for: PlannerDateHelper.date(forDayIndex: index, calendar: calendar))
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledDayIndex)
            .scrollIndicators(.hidden)
        }
        .onChange(of: scrolledDayIndex) { _, newValue in
            guard let newValue,
                  newValue != PlannerDateHelper.dayIndex(for: selectedDate, calendar: calendar)
            else { return }
            selectedDate = PlannerDateHelper.date(forDayIndex: newValue, calendar: calendar)
            // 날짜를 넘기면 입력 중이던 추가 행을 닫는다 — 어느 날에 넣는지 헷갈린다.
            if isEditMode { isEditMode = false }
        }
        .onChange(of: selectedDate) { _, newValue in
            let index = PlannerDateHelper.dayIndex(for: newValue, calendar: calendar)
            if scrolledDayIndex != index { scrolledDayIndex = index }
        }
    }

    /// 앞뒤 10년. 이보다 멀리 갈 일은 날짜 선택으로 뛴다.
    private var pageRange: ClosedRange<Int> {
        let center = PlannerDateHelper.dayIndex(for: today, calendar: calendar)
        return (center - 3650)...(center + 3650)
    }

    @ViewBuilder
    private func page(for date: Date) -> some View {
        if isEmpty(date) {
            emptyState(for: date)
        } else {
            list(for: date)
        }
    }

    private func list(for date: Date) -> some View {
        List {
            ForEach(entries(on: date), id: \.persistentModelID) { entry in
                PlannerScheduleCard(entry: entry)
                    .plannerCardRow()
            }

            ForEach(planItems(on: date), id: \.persistentModelID) { item in
                PlannerTaskCard(
                    title: item.title,
                    subtitle: item.relatedSubjectName,
                    isDone: item.isDone,
                    onToggle: { item.isDone.toggle() }
                )
                .plannerCardRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        context.delete(item)
                    } label: {
                        Label("삭제", systemImage: "trash.fill")
                    }
                    Button {
                        editingItem = item
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func emptyState(for date: Date) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(PlannerDateHelper.isSameDay(date, today, calendar: calendar)
                 ? "오늘 할 일이 없어요"
                 : "이 날 할 일이 없어요")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("+ 버튼을 눌러 추가하세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 인라인 추가

    private var addRow: some View {
        HStack(spacing: 12) {
            Circle()
                .strokeBorder(Color.accentColor, lineWidth: 1.5)
                .frame(width: 29, height: 29)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            TextField("새 할 일 추가…", text: $inlineTitle)
                .focused($isInlineFieldFocused)
                .submitLabel(.done)
                .onSubmit(commitInlineItem)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: PlannerCardMetrics.height,
               maxHeight: PlannerCardMetrics.height, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    /// 연달아 여러 개를 넣을 수 있도록 입력 후에도 포커스를 유지한다.
    private func commitInlineItem() {
        let trimmed = inlineTitle.trimmed
        guard !trimmed.isEmpty else { return }
        inlineTitle = ""
        isInlineFieldFocused = true

        let item = PlanItem(
            title: trimmed,
            date: PlannerDateHelper.startOfDay(selectedDate, calendar: calendar)
        )
        context.insert(item)
    }
}

/// 카드 높이 — 부제가 있든 없든 같게 고정해 목록의 리듬이 흔들리지 않게 한다.
enum PlannerCardMetrics {
    static let height: CGFloat = 72
}

extension View {
    /// 카드가 리스트 행의 기본 배경·구분선 없이 떠 보이게 한다.
    func plannerCardRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

/// 시간표 카드 — 체크박스가 없다. 수업 시간은 완료할 대상이 아니라 그날의 일과다.
struct PlannerScheduleCard: View {
    let entry: TimetableEntry

    private var tint: Color {
        switch entry.type {
        case .school: Color("ScheduleSchool")
        case .academy: Color("ScheduleAcademy")
        }
    }

    private var iconName: String {
        switch entry.type {
        case .school: "building.columns"
        case .academy: "book"
        }
    }

    private var typeLabel: String {
        switch entry.type {
        case .school: String(localized: "학교")
        case .academy: String(localized: "학원")
        }
    }

    private var timeText: String {
        let start = entry.startTime.formatted(.dateTime.hour().minute())
        let end = entry.endTime.formatted(.dateTime.hour().minute())
        return "\(start) – \(end)"
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 4, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.title)
                    .font(.body)
                HStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(.caption2)
                        .accessibilityHidden(true)
                    Text(verbatim: "\(typeLabel) · \(timeText)")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: PlannerCardMetrics.height,
               maxHeight: PlannerCardMetrics.height, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(typeLabel) 일정, \(entry.title), \(timeText)")
    }
}

/// 할 일 카드 — 탭하면 완료를 토글한다.
///
/// 제자리 이름 수정은 두지 않는다. 스와이프의 "수정"이 `PlanItemFormView`를 열어 제목뿐
/// 아니라 날짜·과목까지 고칠 수 있으므로, 제목만 고치는 경로를 따로 두면 편집 경로가
/// 두 개로 갈린다.
struct PlannerTaskCard: View {
    let title: String
    var subtitle: String?
    let isDone: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            checkmark

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.body)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: PlannerCardMetrics.height,
               maxHeight: PlannerCardMetrics.height, alignment: .leading)
        .contentShape(Rectangle())
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: isDone ? .light : .medium).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) { onToggle() }
        }
    }

    /// 완료 표시는 색만으로 알리지 않는다 — 체크 기호와 취소선을 함께 쓴다.
    private var checkmark: some View {
        ZStack {
            Circle()
                .strokeBorder(isDone ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1.5)
            if isDone {
                Circle().fill(Color.accentColor)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}
