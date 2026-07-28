import Foundation
import UserNotifications

/// 로컬 알림 스케줄링.
///
/// 푸시 서버를 쓰지 않는다 — 전부 기기 안에서 예약된다.
/// `TextRecognizer`가 Vision을 감싸듯, 이 파일이 `UserNotifications`를 쓰는 유일한 곳이다.
enum NotificationScheduler {

    /// 고정 식별자. 매번 새 알림을 쌓지 않고 기존 예약을 교체한다.
    private enum Identifier {
        static let planReminder = "studion.planReminder"
        static let reviewReminder = "studion.reviewReminder"
    }

    /// 권한을 요청한다. 거부해도 앱은 그대로 동작한다.
    static func requestAuthorization() async -> Bool {
        // .badge를 요청하지 않는다 — 숫자 배지는 학생에게 압박으로 읽힌다.
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 매일 같은 시각에 오늘 계획을 상기시킨다.
    static func schedulePlanReminder(hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "오늘 계획")
        content.body = String(localized: "오늘 할 일을 확인해 보세요.")
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let request = UNNotificationRequest(
            identifier: Identifier.planReminder,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.planReminder])
        try? await center.add(request)
    }

    /// 복습할 카드가 있을 때만 예약한다. 0장이면 알림을 걸지 않는다.
    static func scheduleReviewReminder(dueCount: Int, hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.reviewReminder])

        guard dueCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "복습")
        // 밀렸다고 말하지 않는다. 사실만 담담하게 전한다.
        content.body = String(localized: "복습할 카드 \(dueCount)장이 있어요.")
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let request = UNNotificationRequest(
            identifier: Identifier.reviewReminder,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await center.add(request)
    }

    static func cancelPlanReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Identifier.planReminder])
    }

    static func cancelReviewReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Identifier.reviewReminder])
    }
}
