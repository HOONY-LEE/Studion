import Foundation

/// 개발자 탭이 쓰는 Supabase 프로젝트 연결 정보.
///
/// 값은 `Config/DevChatSecrets.local.xcconfig`(gitignore 대상)에서 온다.
/// 그 파일이 없으면 빈 문자열로 빌드되고, 이 타입은 그 상태를 "미설정"으로 보고한다 —
/// 크래시하지 않고 개발자 탭이 안내 화면만 보여준다. → `docs/10-developer-chat.md` §6, §7
enum DevChatConfig {
    static var supabaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "DevChatSupabaseURL") as? String,
              !raw.isEmpty
        else { return nil }
        return URL(string: raw)
    }

    static var supabaseAnonKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "DevChatSupabaseAnonKey") as? String,
              !raw.isEmpty
        else { return nil }
        return raw
    }

    static var isConfigured: Bool {
        supabaseURL != nil && supabaseAnonKey != nil
    }
}
