import SwiftUI
import SwiftData

/// 플래너 탭. Gradin의 캘린더 상단 바 구성을 따른다 — 날짜 버튼 + "오늘" + 보기 전환 메뉴.
///
/// 보기는 세 가지다. **캘린더 격자는 월간·주간뿐이고, 일간은 격자가 아니라 그날의
/// 할 일 목록**(`PlannerTodayView`)이다 — 하루는 칸으로 나눠 볼 것이 아니라 해야 할 일을
/// 훑는 화면이라는 판단이다.
struct PlannerView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case today, week, month

        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .today: "일간"
            case .week: "주간"
            case .month: "월간"
            }
        }

        var icon: String {
            switch self {
            case .today: "checklist"
            case .week: "calendar.day.timeline.left"
            case .month: "calendar"
            }
        }
    }

    @Environment(\.calendar) private var calendar

    @State private var mode: Mode = .today
    @State private var selectedDate = Date()
    @State private var isPickingDate = false
    @State private var isShowingTimetable = false
    /// 상단 + 를 누르면 켜지고, 각 보기가 자기 방식으로 처리한 뒤 스스로 끈다.
    ///
    /// "추가"의 의미가 보기마다 다르기 때문에 상단 바가 직접 시트를 띄우지 않는다 —
    /// 일간은 아래에서 입력 줄이 올라오고, 주간은 할 일 폼, 월간은 일정 폼이다.
    @State private var addRequested = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                Group {
                    switch mode {
                    case .today:
                        PlannerTodayView(selectedDate: $selectedDate, addRequested: $addRequested)
                    case .week:
                        PlannerWeekView(selectedDate: $selectedDate, addRequested: $addRequested)
                    case .month:
                        PlannerMonthView(selectedDate: $selectedDate, addRequested: $addRequested)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isPickingDate) {
                datePicker
            }
            .sheet(isPresented: $isShowingTimetable) {
                NavigationStack {
                    TimetableListView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("닫기") { isShowingTimetable = false }
                            }
                        }
                }
            }
            .onAppear {
                selectedDate = PlannerDateHelper.startOfDay(selectedDate, calendar: calendar)
            }
        }
    }

    // MARK: - 상단 바

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                isPickingDate = true
            } label: {
                HStack(spacing: 6) {
                    Text(verbatim: dateButtonText)
                        .font(.system(size: 17, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(PlannerPillButtonStyle())

            if !isViewingToday {
                Button {
                    withAnimation {
                        selectedDate = PlannerDateHelper.startOfDay(Date(), calendar: calendar)
                    }
                } label: {
                    Text("오늘")
                        .font(.system(size: 17))
                }
                .buttonStyle(PlannerPillButtonStyle())
            }

            Spacer(minLength: 0)

            Menu {
                Picker("보기", selection: $mode) {
                    ForEach(Mode.allCases) { item in
                        Label(item.label, systemImage: item.icon).tag(item)
                    }
                }
                Divider()
                // 상단 바를 직접 그리면서 내비게이션 바를 감췄으므로, 시간표 관리로 가는
                // 유일한 통로가 이 메뉴다.
                Button {
                    isShowingTimetable = true
                } label: {
                    Label("시간표 관리", systemImage: "calendar.badge.clock")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .medium))
                    Text(mode.label)
                        .font(.system(size: 17))
                }
            }
            .buttonStyle(PlannerPillButtonStyle())
            .accessibilityLabel("보기 바꾸기")

            Button {
                addRequested = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(PlannerPillButtonStyle())
            .accessibilityLabel(mode == .month ? "일정 추가" : "할 일 추가")
        }
        .tint(.primary)
    }

    /// 보기에 따라 필요한 만큼만 보여준다 — 월간에서 일까지 적으면 무슨 날인지 오해를 준다.
    private var dateButtonText: String {
        switch mode {
        case .month:
            return selectedDate.formatted(.dateTime.year().month())
        case .week, .today:
            return selectedDate.formatted(.dateTime.year().month().day())
        }
    }

    private var isViewingToday: Bool {
        PlannerDateHelper.isSameDay(selectedDate, Date(), calendar: calendar)
    }

    // MARK: - 날짜 선택

    private var datePicker: some View {
        NavigationStack {
            DatePicker(
                "날짜 선택",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            .navigationTitle("날짜 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { isPickingDate = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 상단 바 버튼 — 옅은 알약 배경. Gradin은 유리 재질(`glassEffect`)을 쓰는데 그건 그쪽
/// 테마 레이어라, Studion에서는 시스템 채움색으로 같은 자리를 채운다.
struct PlannerPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Color(.secondarySystemFill), in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#Preview {
    PlannerView()
}
