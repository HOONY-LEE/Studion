import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

/// 집중 모드(다른 앱 차단). Screen Time API로 앱을 가린다.
///
/// - Important: **`com.apple.developer.family-controls` entitlement가 있어야 동작한다.**
///   이 권한은 유료 멤버십과 별개로 애플에 따로 신청해 승인받아야 하며, 승인 전에는
///   `requestAuthorization`이 실패한다. 그래서 실패를 크래시가 아니라 **안내로 다룬다** —
///   승인 전에도 앱의 다른 기능은 그대로 쓸 수 있어야 한다.
///   → `docs/09-app-shield.md` §6
///
/// 선택한 앱 토큰은 SwiftData·CloudKit에 넣지 않고 `UserDefaults`에 둔다. 토큰은 불투명하고
/// **기기에 묶인 값**이라 다른 기기로 동기화하면 의미가 없다 (→ 문서 §3).
@MainActor
@Observable
final class AppShieldStore {
    enum Authorization: Equatable {
        case unknown
        case approved
        /// 거부되었거나 entitlement가 없어 요청 자체가 실패했다.
        case unavailable(String)
    }

    private(set) var authorization: Authorization = .unknown
    /// 지금 차단이 걸려 있는지.
    private(set) var isShielding = false

    /// 차단할 앱·카테고리 선택. 바뀌면 바로 저장한다.
    var selection = FamilyActivitySelection() {
        didSet { persistSelection() }
    }

    var strength: FocusStrength {
        didSet { defaults.set(strength.rawValue, forKey: Key.strength) }
    }

    /// 할 일 완료율로 자동 해제할지.
    var unlocksByTaskCompletion: Bool {
        didSet { defaults.set(unlocksByTaskCompletion, forKey: Key.unlockByTasks) }
    }

    /// 목표 완료율 (0…1).
    var requiredCompletionRate: Double {
        didSet { defaults.set(requiredCompletionRate, forKey: Key.requiredRate) }
    }

    private let store = ManagedSettingsStore()
    private let defaults: UserDefaults

    private enum Key {
        static let selection = "focus.selection"
        static let strength = "focus.strength"
        static let unlockByTasks = "focus.unlockByTasks"
        static let requiredRate = "focus.requiredRate"
        static let unlockedOn = "focus.unlockedOn"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        strength = FocusStrength(rawValue: defaults.string(forKey: Key.strength) ?? "")
            ?? .default
        unlocksByTaskCompletion = defaults.object(forKey: Key.unlockByTasks) as? Bool ?? true
        requiredCompletionRate = defaults.object(forKey: Key.requiredRate) as? Double ?? 0.8

        if let data = defaults.data(forKey: Key.selection),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        }
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    // MARK: - 권한

    func requestAuthorization() async {
        do {
            // `.individual` — 학생 본인의 도구다. 부모 통제(.child)는 쓰지 않는다 (문서 §7).
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorization = .approved
        } catch {
            authorization = .unavailable(error.localizedDescription)
        }
    }

    // MARK: - 차단 걸기 / 풀기

    /// 고른 앱을 가린다. 아무것도 고르지 않았으면 아무 일도 하지 않는다.
    func startShielding() {
        guard case .approved = authorization, hasSelection else { return }
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        isShielding = true
    }

    /// 차단을 푼다. 긴급 해제도 이 경로를 쓴다 — **기록을 남기지 않는다** (문서 §5-2).
    func stopShielding() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isShielding = false
    }

    // MARK: - 할 일 연동

    /// 오늘 할 일 완료 상황으로 차단을 유지할지 정한다.
    ///
    /// 해제되면 **그날은 다시 잠기지 않도록** 날짜를 기록한다 (문서 §2-2).
    @discardableResult
    func applyTaskRule(completed: Int, total: Int, calendar: Calendar) -> FocusUnlockRule.Outcome {
        let today = calendar.startOfDay(for: Date())
        let outcome = FocusUnlockRule.evaluate(
            completed: completed,
            total: total,
            requiredRate: requiredCompletionRate,
            alreadyUnlockedToday: unlockedDate.map { calendar.isDate($0, inSameDayAs: today) } ?? false
        )

        switch outcome {
        case .shield:
            startShielding()
        case .unlocked:
            if unlockedDate == nil || !calendar.isDate(unlockedDate!, inSameDayAs: today) {
                unlockedDate = today
            }
            stopShielding()
        }
        return outcome
    }

    /// 오늘 이미 해제된 날짜. 자정이 지나면 자연히 무효가 된다.
    private var unlockedDate: Date? {
        get { defaults.object(forKey: Key.unlockedOn) as? Date }
        set { defaults.set(newValue, forKey: Key.unlockedOn) }
    }

    private func persistSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: Key.selection)
    }
}
