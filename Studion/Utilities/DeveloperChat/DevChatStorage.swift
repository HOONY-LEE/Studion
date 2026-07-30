#if DEBUG
import Foundation
import Supabase

/// 첨부 파일 저장소. 버킷은 비공개이며 접근 권한은 방 멤버십으로 검사한다
/// (→ `supabase/dev-chat/004_reactions_attachments.sql`).
///
/// 서명 URL(`createSignedURL`)이 아니라 `download(path:)`를 쓴다 — SDK가 인증을 알아서
/// 붙여주므로 만료 시각을 관리할 필요가 없다. 대신 받은 바이트를 여기서 캐시한다.
@MainActor
final class DevChatStorage {
    static let bucket = "dev-chat"
    static let shared = DevChatStorage()

    /// 경로 → 내려받은 원본 바이트. 메모리에만 둔다(개발용 도구라 디스크 캐시까지 두지 않는다).
    private var cache: [String: Data] = [:]
    /// 같은 사진을 여러 셀이 동시에 요청할 때 다운로드가 중복되지 않게 진행 중인 작업을 공유한다.
    private var inFlight: [String: Task<Data?, Never>] = [:]

    private init() {}

    func cached(_ path: String) -> Data? { cache[path] }

    func data(for path: String, client: SupabaseClient) async -> Data? {
        if let hit = cache[path] { return hit }
        if let running = inFlight[path] { return await running.value }

        let task = Task<Data?, Never> { [client] in
            try? await client.storage.from(Self.bucket).download(path: path)
        }
        inFlight[path] = task
        let data = await task.value
        inFlight[path] = nil
        if let data { cache[path] = data }
        return data
    }
}
#endif
