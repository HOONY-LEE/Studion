import Foundation
import CryptoKit
import Security

/// Sign in with Apple + Supabase 조합이 요구하는 재사용 방지 값.
///
/// 애플에는 이 값의 해시를 보내고, Supabase에는 원본을 보낸다 — Supabase가 같은
/// 해시로 검증해 토큰이 이번 로그인 시도에서 나온 게 맞는지 확인한다. 온보딩과
/// 팀 메신저 두 화면이 똑같은 절차를 쓰므로 한 곳에 모아 중복을 없앤다.
enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randomByte: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &randomByte)
            if randomByte < charset.count {
                result.append(charset[Int(randomByte)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
