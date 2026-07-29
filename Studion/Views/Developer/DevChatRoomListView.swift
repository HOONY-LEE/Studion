#if DEBUG
import SwiftUI

/// 채팅방 목록. 애플 메시지 앱의 대화 목록과 같은 자리.
struct DevChatRoomListView: View {
    let authService: DevChatAuthService
    let profile: DevProfile

    @State private var roomService: DevChatRoomService?
    /// 1:1 방은 이름이 없어 상대방 표시 이름을 따로 계산해 캐시한다.
    @State private var resolvedTitles: [UUID: String] = [:]
    @State private var isShowingUserSearch = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(roomService?.rooms ?? []) { room in
                NavigationLink {
                    DevChatRoomView(
                        client: authService.client,
                        room: room,
                        title: title(for: room),
                        profile: profile
                    )
                } label: {
                    Text(verbatim: title(for: room))
                }
            }
        }
        .overlay {
            if let roomService, roomService.rooms.isEmpty {
                EmptyStateView(
                    systemImage: "bubble.left.and.bubble.right",
                    title: "대화가 없어요",
                    message: "오른쪽 위 버튼으로 팀원을 찾아 대화를 시작하세요."
                )
            }
        }
        .navigationTitle("개발자")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("로그아웃") {
                    Task { try? await authService.signOut() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingUserSearch = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $isShowingUserSearch) {
            if let roomService {
                DevUserSearchView(roomService: roomService, profile: profile) {
                    Task { await refresh() }
                }
            }
        }
        .task {
            if roomService == nil {
                roomService = DevChatRoomService(client: authService.client)
            }
            await refresh()
        }
        .refreshable { await refresh() }
        .alert("문제가 발생했어요", isPresented: errorAlertBinding) {
            Button("확인") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func title(for room: DevChatRoom) -> String {
        if let name = room.name, !name.isEmpty { return name }
        return resolvedTitles[room.id] ?? "대화"
    }

    private func refresh() async {
        guard let roomService else { return }
        do {
            try await roomService.loadRooms()
            await resolveTitles(using: roomService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveTitles(using roomService: DevChatRoomService) async {
        for room in roomService.rooms where room.name == nil && resolvedTitles[room.id] == nil {
            guard let members = try? await roomService.members(of: room.id) else { continue }
            let other = members.first { $0.id != profile.id }
            resolvedTitles[room.id] = other?.displayName ?? "대화"
        }
    }
}
#endif
