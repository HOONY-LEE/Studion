import Foundation
import Supabase

/// 내 프로필(이름·사진) 고치기.
///
/// Apple 로그인은 이름을 **최초 인증 한 번만** 내려준다. 그 기회를 놓치면 이름이
/// 이메일 앞부분이나 `'팀원'`으로 남는데, 그걸 사용자가 직접 고칠 수 있어야 한다.
/// → `docs/10-developer-chat.md` §2
@MainActor
final class DevChatProfileService {
    /// 프로필 사진 버킷. 첨부파일(`dev-chat`)과 분리한다 — 접근 규칙이 다르다.
    /// 첨부는 같은 방 멤버만, 사진은 로그인한 팀원 누구나 볼 수 있어야 한다.
    static let avatarBucket = "dev-avatars"

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// 표시 이름을 바꾼다.
    func updateDisplayName(_ name: String, userID: UUID) async throws {
        try await client
            .from("dev_profiles")
            .update(["display_name": name])
            .eq("id", value: userID.uuidString)
            .execute()
    }

    /// 프로필 사진을 올리고 경로를 프로필에 기록한다.
    ///
    /// 경로 첫 폴더를 본인 id로 두는 것이 **접근 규칙 그 자체다** — 버킷 정책이 그 폴더명을
    /// 보고 남의 사진을 덮어쓰지 못하게 막는다 (첨부파일이 방 id로 하는 것과 같은 방식).
    /// 파일 이름에 UUID를 새로 붙여 캐시가 옛 사진을 계속 보여주는 일을 막는다.
    func uploadAvatar(_ data: Data, userID: UUID) async throws -> String {
        let path = "\(userID.uuidString)/\(UUID().uuidString).jpg"

        try await client.storage
            .from(Self.avatarBucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

        try await client
            .from("dev_profiles")
            .update(["avatar_path": path])
            .eq("id", value: userID.uuidString)
            .execute()

        DevChatAvatarStore.shared.prime(path: path, data: data)
        return path
    }

    /// 프로필 사진을 지운다. Storage의 파일까지 지우진 않는다 — 참조만 끊어도 화면에서는
    /// 사라지고, 실패해도 사용자가 할 일이 없는 정리 작업이라 여기서 붙들지 않는다.
    func removeAvatar(userID: UUID) async throws {
        try await client
            .from("dev_profiles")
            .update(["avatar_path": String?.none])
            .eq("id", value: userID.uuidString)
            .execute()
    }

    /// 바뀐 프로필을 다시 읽어온다.
    func reloadProfile(userID: UUID) async throws -> DevProfile? {
        let profiles: [DevProfile] = try await client
            .from("dev_profiles")
            .select()
            .eq("id", value: userID.uuidString)
            .execute()
            .value
        return profiles.first
    }
}

/// 프로필 사진 캐시. 첨부파일 캐시(`DevChatStorage`)와 같은 구조지만 버킷이 달라 분리한다.
///
/// 대화 목록은 한 화면에 사진을 여러 장 띄우므로, 같은 사진을 셀마다 새로 내려받지 않도록
/// 진행 중인 다운로드를 공유한다.
@MainActor
final class DevChatAvatarStore {
    static let shared = DevChatAvatarStore()

    private var cache: [String: Data] = [:]
    private var inFlight: [String: Task<Data?, Never>] = [:]

    private init() {}

    func cached(_ path: String) -> Data? { cache[path] }

    func prime(path: String, data: Data) { cache[path] = data }

    func data(for path: String, client: SupabaseClient) async -> Data? {
        if let hit = cache[path] { return hit }
        if let running = inFlight[path] { return await running.value }

        let task = Task<Data?, Never> { [client] in
            try? await client.storage.from(DevChatProfileService.avatarBucket).download(path: path)
        }
        inFlight[path] = task
        let data = await task.value
        inFlight[path] = nil
        if let data { cache[path] = data }
        return data
    }
}
