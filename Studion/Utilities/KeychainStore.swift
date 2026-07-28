import Foundation
import Security

/// Sign in with Apple이 돌려준 사용자 식별자를 보관한다.
///
/// **이메일·이름은 저장하지 않는다.** 앱이 필요로 하는 것은 "같은 사용자인가"뿐이며,
/// 그 이상의 개인정보를 보관하지 않는 것이 이 앱의 원칙이다.
enum KeychainStore {

    private static let service = "com.studion.app.signInWithApple"
    private static let account = "userIdentifier"

    static func save(userIdentifier: String) {
        guard let data = userIdentifier.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func loadUserIdentifier() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
