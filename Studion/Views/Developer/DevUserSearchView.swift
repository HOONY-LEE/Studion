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
                    Text(verbatim: user.displayName)
                }
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
