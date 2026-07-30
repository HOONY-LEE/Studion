#if DEBUG
import SwiftUI

/// 대화 목록. 애플 메시지의 목록을 따라간다 — 아바타, 이름, 마지막 메시지 미리보기,
/// 오른쪽에 시각. 검색으로 대화를 걸러낼 수 있다.
struct DevChatRoomListView: View {
    let authService: DevChatAuthService
    let profile: DevProfile

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    @State private var roomService: DevChatRoomService?
    /// 1:1 방은 이름이 없어 상대방 표시 이름을 따로 계산해 캐시한다.
    @State private var resolvedTitles: [UUID: String] = [:]
    @State private var lastMessages: [UUID: DevMessage] = [:]
    @State private var searchText = ""
    @State private var isShowingUserSearch = false
    @State private var errorMessage: String?

    private var rooms: [DevChatRoom] {
        let all = roomService?.rooms ?? []
        // 최근 대화가 위로 온다. 메시지가 없는 방은 만든 시각을 기준으로 둔다.
        let sorted = all.sorted { left, right in
            let leftDate = lastMessages[left.id]?.createdAt ?? left.createdAt
            let rightDate = lastMessages[right.id]?.createdAt ?? right.createdAt
            return leftDate > rightDate
        }

        let query = searchText.trimmed
        guard !query.isEmpty else { return sorted }
        return sorted.filter { room in
            title(for: room).localizedStandardContains(query)
                || (lastMessages[room.id]?.body.localizedStandardContains(query) ?? false)
        }
    }

    var body: some View {
        List {
            ForEach(rooms) { room in
                NavigationLink {
                    DevChatRoomView(
                        client: authService.client,
                        room: room,
                        title: title(for: room),
                        profile: profile
                    )
                } label: {
                    row(for: room)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 8))
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "검색")
        .overlay {
            if let roomService, roomService.rooms.isEmpty {
                EmptyStateView(
                    systemImage: "bubble.left.and.bubble.right",
                    title: "대화가 없어요",
                    message: "오른쪽 위 버튼으로 팀원을 찾아 대화를 시작하세요."
                )
            } else if !searchText.trimmed.isEmpty, rooms.isEmpty {
                ContentUnavailableView.search(text: searchText)
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
                .accessibilityLabel("새 대화")
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

    // MARK: - 목록 한 줄

    private func row(for room: DevChatRoom) -> some View {
        HStack(alignment: .top, spacing: 12) {
            DevChatAvatar(
                displayName: title(for: room),
                isGroup: room.isGroup
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: title(for: room))
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    // 오른쪽 화살표는 NavigationLink가 직접 그린다 — 여기서 따로 그리면 두 개가 된다.
                    if let last = lastMessages[room.id] {
                        Text(verbatim: DevChatTimestamp.listLabel(
                            for: last.createdAt, now: .now, calendar: calendar, locale: locale
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Text(preview(for: room))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .contentShape(Rectangle())
    }

    /// 마지막 메시지 미리보기. 내가 보낸 것이면 애플 메시지처럼 "나: "를 앞에 붙인다.
    private func preview(for room: DevChatRoom) -> String {
        guard let last = lastMessages[room.id] else {
            return String(localized: "메시지가 없습니다", locale: locale)
        }
        let body = last.body.replacingOccurrences(of: "\n", with: " ")
        guard last.senderId == profile.id else { return body }
        return "\(String(localized: "나", locale: locale)): \(body)"
    }

    // MARK: - 데이터

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func title(for room: DevChatRoom) -> String {
        if let name = room.name, !name.isEmpty { return name }
        return resolvedTitles[room.id] ?? String(localized: "대화", locale: locale)
    }

    private func refresh() async {
        guard let roomService else { return }
        do {
            try await roomService.loadRooms()
            lastMessages = try await roomService.lastMessages(
                for: roomService.rooms.map(\.id)
            )
            await resolveTitles(using: roomService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveTitles(using roomService: DevChatRoomService) async {
        for room in roomService.rooms where room.name == nil && resolvedTitles[room.id] == nil {
            guard let members = try? await roomService.members(of: room.id) else { continue }
            let other = members.first { $0.id != profile.id }
            resolvedTitles[room.id] = other?.displayName
                ?? String(localized: "대화", locale: locale)
        }
    }
}
#endif
