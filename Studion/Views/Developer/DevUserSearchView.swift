#if DEBUG
import SwiftUI

/// 팀원을 검색해 1:1 대화를 시작한다. 팀 규모가 작다는 전제로 전체 프로필을
/// 받아 클라이언트에서 이름으로 거른다 (→ `docs/10-developer-chat.md` §1).
struct DevUserSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let roomService: DevChatRoomService
    let profile: DevProfile
    let onRoomCreated: () -> Void

    @State private var query = ""
    @State private var allUsers: [DevProfile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var results: [DevProfile] {
        let others = allUsers.filter { $0.id != profile.id }
        let trimmed = query.trimmed
        guard !trimmed.isEmpty else { return others }
        return others.filter { $0.displayName.localizedStandardContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            List(results) { user in
                Button {
                    startConversation(with: user)
                } label: {
                    row(for: user)
                }
                // List 안의 Button은 기본 스타일이 라벨 전체를 accentColor로 물들인다 —
                // .plain으로 꺼야 안의 Text에 준 foregroundStyle이 실제로 적용된다.
                .buttonStyle(.plain)
            }
            .searchable(text: $query, prompt: "표시 이름 검색")
            .navigationTitle("팀원 찾기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .overlay {
                if isLoading { ProgressView() }
                else if allUsers.filter({ $0.id != profile.id }).isEmpty {
                    ContentUnavailableView("아직 다른 팀원이 없어요", systemImage: "person.2.slash")
                }
            }
            .task { await loadUsers() }
            .alert("문제가 발생했어요", isPresented: errorAlertBinding) {
                Button("확인") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    /// 대화 목록 행과 같은 구성 — 아바타 + 이름 + 이메일. 이름은 Button 기본 틴트(accentColor)
    /// 대신 일반 텍스트 색으로 보이도록 `.foregroundStyle(.primary)`를 명시한다.
    private func row(for user: DevProfile) -> some View {
        HStack(spacing: 12) {
            DevChatAvatar(displayName: user.displayName, diameter: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: user.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                if let email = user.email, !email.isEmpty {
                    Text(verbatim: email)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            allUsers = try await roomService.allProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startConversation(with user: DevProfile) {
        Task {
            do {
                _ = try await roomService.createRoom(name: nil, isGroup: false, memberIDs: [user.id])
                onRoomCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif
