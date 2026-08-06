import Foundation
import Supabase

/// 앱 전체에서 단 하나만 만든다 — `SupabaseClient`는 프로젝트당 하나를 만들어
/// 공유해 쓰도록 설계돼 있다(내부적으로 세션 감시 Task를 스스로 띄운다).
enum DevChatClient {
    static let shared: SupabaseClient? = {
        guard let url = DevChatConfig.supabaseURL, let key = DevChatConfig.supabaseAnonKey else {
            return nil
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}
