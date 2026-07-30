import Foundation

/// 집중 모드 해제 판단. `docs/09-app-shield.md` §2-2의 규칙을 코드로 옮긴 것이다.
///
/// 순수 Swift로 둔다 — 이 규칙이 틀리면 학생 폰이 부당하게 잠기므로 테스트로 못박는다.
enum FocusUnlockRule {

    enum Outcome: Equatable {
        /// 차단을 건다.
        case shield
        /// 차단하지 않는다(이유를 함께 담아 화면에 그대로 알린다).
        case unlocked(Reason)

        enum Reason: Equatable {
            /// 오늘 할 일이 하나도 없다.
            case noTasksToday
            /// 목표 완료율을 채웠다.
            case goalReached
            /// 오늘 이미 한 번 풀렸다.
            case alreadyUnlockedToday
        }
    }

    /// 오늘 할 일 완료율로 차단 여부를 정한다.
    ///
    /// - Parameters:
    ///   - completed: 오늘 완료한 할 일 수
    ///   - total: 오늘 할 일 수 (지난 날짜의 할 일은 세지 않는다)
    ///   - requiredRate: 목표 완료율 (0…1)
    ///   - alreadyUnlockedToday: 오늘 이미 해제된 적이 있는지
    static func evaluate(
        completed: Int,
        total: Int,
        requiredRate: Double,
        alreadyUnlockedToday: Bool
    ) -> Outcome {
        // 한 번 풀리면 그날은 다시 잠기지 않는다. 할 일을 지워 완료율이 떨어져도 마찬가지다 —
        // 해제를 되돌리면 사용자가 앱을 신뢰할 수 없게 된다.
        if alreadyUnlockedToday { return .unlocked(.alreadyUnlockedToday) }

        // 할 일을 안 만든 것이 폰이 잠길 이유가 되면 안 된다.
        guard total > 0 else { return .unlocked(.noTasksToday) }

        return completionRate(completed: completed, total: total) >= requiredRate
            ? .unlocked(.goalReached)
            : .shield
    }

    /// 완료율. 완료 수가 전체를 넘는 어긋난 입력에서도 1을 넘지 않는다.
    static func completionRate(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }
}

/// 차단 강도. `docs/09-app-shield.md` §4.
///
/// 어떤 강도에서도 **긴급 해제는 항상 있다** (§5-2). 강도는 "얼마나 마찰을 주는가"이지
/// "빠져나갈 수 있는가"가 아니다.
enum FocusStrength: String, CaseIterable, Identifiable, Codable {
    case gentle, normal, strict

    var id: String { rawValue }

    /// 기본값은 "보통". 처음 켜는 사용자에게 "엄격하게"를 기본으로 주지 않는다.
    static let `default`: FocusStrength = .normal

    var label: String {
        switch self {
        case .gentle: String(localized: "부드럽게")
        case .normal: String(localized: "보통")
        case .strict: String(localized: "엄격하게")
        }
    }

    var explanation: String {
        switch self {
        case .gentle: String(localized: "차단 화면에서 바로 열 수 있어요. 무심코 여는 것만 막습니다.")
        case .normal: String(localized: "잠깐 기다린 뒤 열 수 있어요. 충동을 한 번 끊습니다.")
        case .strict: String(localized: "할 일을 채우거나 집중을 끝내야 열려요. 긴급 해제는 항상 됩니다.")
        }
    }
}
