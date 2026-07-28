import SwiftUI
import SwiftData
import UserNotifications

/// 알림 설정.
///
/// 권한 거부는 막다른 길이 아니다 — 얼럿 대신 인라인 안내와 시스템 설정 링크를 둔다.
struct NotificationSettingsView: View {
    @Environment(\.calendar) private var calendar

    @AppStorage(PreferenceKey.planReminderEnabled) private var planEnabled = false
    @AppStorage(PreferenceKey.planReminderHour) private var planHour = 21
    @AppStorage(PreferenceKey.planReminderMinute) private var planMinute = 0
    @AppStorage(PreferenceKey.reviewReminderEnabled) private var reviewEnabled = false

    @Query private var notes: [WrongAnswerNote]

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private var isDenied: Bool { authorizationStatus == .denied }

    private var dueCount: Int {
        notes.filter {
            ReviewScheduler.isDue(nextReviewDate: $0.nextReviewDate, on: Date(), calendar: calendar)
        }.count
    }

    /// `@AppStorage`가 `Date`를 지원하지 않아 시·분을 정수로 나눠 저장한다.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                calendar.date(from: DateComponents(hour: planHour, minute: planMinute)) ?? Date()
            },
            set: { newValue in
                let components = calendar.dateComponents([.hour, .minute], from: newValue)
                planHour = components.hour ?? 21
                planMinute = components.minute ?? 0
            }
        )
    }

    var body: some View {
        Form {
            if isDenied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("알림이 꺼져 있어요")
                            .font(.subheadline.weight(.medium))
                        Text("iOS 설정에서 Studion 알림을 켜면 사용할 수 있습니다.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("설정 열기") { openSystemSettings() }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Toggle("오늘 계획 알림", isOn: $planEnabled)
                if planEnabled {
                    DatePicker("알림 시간", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text("매일 정해진 시간에 오늘 할 일을 알려줍니다.")
            }

            Section {
                Toggle("복습 알림", isOn: $reviewEnabled)
            } footer: {
                Text("복습할 카드가 있을 때만 알려줍니다. 없으면 알림이 오지 않습니다.")
            }
        }
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isDenied)
        .task { await refreshStatus() }
        .onChange(of: planEnabled) { _, _ in Task { await applySettings() } }
        .onChange(of: reviewEnabled) { _, _ in Task { await applySettings() } }
        .onChange(of: planHour) { _, _ in Task { await applySettings() } }
        .onChange(of: planMinute) { _, _ in Task { await applySettings() } }
    }

    private func refreshStatus() async {
        authorizationStatus = await NotificationScheduler.authorizationStatus()
    }

    private func applySettings() async {
        if planEnabled || reviewEnabled {
            if authorizationStatus == .notDetermined {
                _ = await NotificationScheduler.requestAuthorization()
                await refreshStatus()
            }
            guard authorizationStatus != .denied else { return }
        }

        if planEnabled {
            await NotificationScheduler.schedulePlanReminder(hour: planHour, minute: planMinute)
        } else {
            NotificationScheduler.cancelPlanReminder()
        }

        if reviewEnabled {
            await NotificationScheduler.scheduleReviewReminder(
                dueCount: dueCount, hour: planHour, minute: planMinute
            )
        } else {
            NotificationScheduler.cancelReviewReminder()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
