import Foundation
import CloudKit

/// 기기의 iCloud 계정 상태.
///
/// 동기화 여부를 **앱이 토글로 통제하지 않는다.** iCloud에 로그인돼 있으면 동기화되고,
/// 아니면 로컬 전용으로 동작한다. 이 값은 그 상태를 사용자에게 있는 그대로 알려주기 위한 것이다.
@MainActor
@Observable
final class CloudAccountStatus {

    enum State {
        case unknown
        /// iCloud 사용 가능 — 기기 간 동기화가 동작한다.
        case available
        /// iCloud 계정이 없거나 사용할 수 없음 — 로컬 전용으로 동작한다.
        case unavailable
        /// 이 빌드가 동기화를 포함하지 않는다 (무료 계정용 구성).
        case notSupportedInThisBuild

        var summary: String {
            switch self {
            case .unknown: String(localized: "확인 중…")
            case .available: String(localized: "이 기기의 iCloud 계정으로 동기화됩니다.")
            case .unavailable: String(localized: "iCloud에 로그인되어 있지 않아 이 기기에만 저장됩니다.")
            case .notSupportedInThisBuild: String(localized: "이 빌드는 동기화 없이 이 기기에만 저장됩니다.")
            }
        }
    }

    private(set) var state: State = .unknown

    func refresh() async {
        #if CLOUD_SYNC
        // entitlement가 없는 빌드에서 CKContainer에 접근하면 실패하므로 이 분기 안에서만 호출한다.
        let status = try? await CKContainer.default().accountStatus()
        state = status == .available ? .available : .unavailable
        #else
        state = .notSupportedInThisBuild
        #endif
    }
}
