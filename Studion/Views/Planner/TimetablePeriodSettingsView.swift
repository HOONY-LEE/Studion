import SwiftUI

/// 교시 시각 맞추기. 학교마다 일과가 달라서 시간표를 쓰기 전에 한 번은 맞춰야 한다.
///
/// 교시마다 시각을 하나하나 적게 하지 않는다 — 8교시면 16번을 입력해야 한다. 대신
/// 네 가지 숫자로 표 전체를 만들고, **결과를 바로 아래에 미리 보여준다.** 숫자만 보고
/// "우리 학교 시간표가 맞나"를 판단하기는 어렵기 때문이다.
struct TimetablePeriodSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    @AppStorage(PreferenceKey.periodSchedule) private var scheduleJSON = ""

    @State private var schedule = SchoolPeriodSchedule.standard

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "1교시 시작",
                        selection: firstPeriodStart,
                        displayedComponents: .hourAndMinute
                    )

                    Stepper(
                        "수업 \(schedule.lessonMinutes)분",
                        value: $schedule.lessonMinutes,
                        in: SchoolPeriodSchedule.lessonMinutesRange,
                        step: 5
                    )

                    Stepper(
                        "쉬는 시간 \(schedule.breakMinutes)분",
                        value: $schedule.breakMinutes,
                        in: SchoolPeriodSchedule.breakMinutesRange,
                        step: 5
                    )
                } header: {
                    Text("수업 시간")
                } footer: {
                    Text("대부분은 1교시 시작 시각만 맞추면 나머지가 따라 맞습니다.")
                }

                Section {
                    Picker("점심시간", selection: $schedule.lunchAfterPeriod) {
                        Text("없음").tag(0)
                        ForEach(1...schedule.periodCount, id: \.self) { number in
                            Text("\(number)교시 뒤").tag(number)
                        }
                    }

                    if schedule.lunchAfterPeriod > 0 {
                        Stepper(
                            "점심 \(schedule.lunchMinutes)분",
                            value: $schedule.lunchMinutes,
                            in: SchoolPeriodSchedule.lunchMinutesRange,
                            step: 5
                        )
                    }
                } header: {
                    Text("점심")
                }

                Section {
                    Stepper(
                        "\(schedule.periodCount)교시까지",
                        value: $schedule.periodCount,
                        in: SchoolPeriodSchedule.periodCountRange
                    )
                } header: {
                    Text("표에 보여줄 교시")
                }

                previewSection
            }
            .navigationTitle("교시 시각")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        scheduleJSON = schedule.sanitized.json
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("기본값") { schedule = .standard }
                        .disabled(schedule == .standard)
                }
            }
            .onAppear { schedule = SchoolPeriodSchedule(json: scheduleJSON) }
            // 교시 수를 줄였는데 점심이 그 뒤에 남아 있으면 갈 곳이 없어진다.
            .onChange(of: schedule.periodCount) { _, count in
                if schedule.lunchAfterPeriod > count { schedule.lunchAfterPeriod = count }
            }
        }
    }

    /// 지금 설정으로 만들어지는 실제 시각. 저장 전에 확인할 수 있어야 한다.
    private var previewSection: some View {
        Section {
            ForEach(schedule.periods) { period in
                LabeledContent("\(period.number)교시") {
                    Text(verbatim: "\(timeLabel(period.startMinutes)) – \(timeLabel(period.endMinutes))")
                        .monospacedDigit()
                }
                // 점심이 어디 들어가는지 눈으로 확인할 수 있어야 실제 일과와 맞춰볼 수 있다.
                if schedule.isBeforeLunch(period) {
                    LabeledContent("점심시간") {
                        Text(verbatim: "\(timeLabel(period.endMinutes)) – \(timeLabel(period.endMinutes + schedule.lunchMinutes))")
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("이렇게 만들어져요")
        }
    }

    /// `DatePicker`는 `Date`를 요구하는데 일과표는 분으로만 들고 있다 — 여기서만 바꿔 쓴다.
    private var firstPeriodStart: Binding<Date> {
        Binding(
            get: {
                let minutes = schedule.firstPeriodStartMinutes
                return calendar.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? Date()
            },
            set: { schedule.firstPeriodStartMinutes = PlannerDateHelper.minutesOfDay($0, calendar: calendar) }
        )
    }

    private func timeLabel(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}
