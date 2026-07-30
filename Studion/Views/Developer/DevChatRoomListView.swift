#if DEBUG
import SwiftUI

/// 대화 목록. WorkChat iOS `ChatListView`의 행 구성을 따른다 — 아바타, 제목(+그룹 인원수),
/// 마지막 메시지 한 줄, 오른쪽 위에 시각과 그 아래 안읽음 배지.
struct DevChatRoomListView: View {
    let authService: DevChatAuthService
    let profile: DevProfile

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    @State private var roomService: DevChatRoomService?
    /// 1:1 방은 이름이 없어 상대방 표시 이름을 따로 계산해 캐시한다.
    @State private var resolvedTitles: [UUID: String] = [:]
    @State private var memberCounts: [UUID: Int] = [:]
    @State private var lastMessages: [UUID: DevMessage] = [:]
    @State private var unreadCounts: [UUID: Int] = [:]
    @State private var searchText = ""
    @State private var isShowingUserSearch = false
    @State private var errorMessage: String?

    private var rooms: [DevChatRoom] {
        let all = roomService?.rooms ?? []
        // 최근 대화가 위로. 메시지가 없는 방은 만든 시각을 기준으로 둔다.
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
        List(rooms) { room in
            NavigationLink {
                DevChatRoomView(
                    client: authService.client,
                    room: room,
                    title: title(for: room),
                    profile: profile
                )
                // 방에 들어가는 즉시 배지를 지운다 — 서버 응답을 기다리면 잠깐 남아 있다.
                .onAppear { unreadCounts[room.id] = 0 }
            } label: {
                row(for: room)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 8))
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "대화 검색")
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

    /// 안읽음 배지가 차지하는 높이. 배지가 없을 때도 같은 높이를 비워 두어 모든 행에서
    /// 시각의 세로 위치가 같게 유지된다(배지 유무로 시각이 들쭉날쭉해지는 것을 막는다).
    private static let badgeHeight: CGFloat = 22

    private func row(for room: DevChatRoom) -> some View {
        HStack(spacing: 12) {
            DevChatAvatar(
                displayName: title(for: room),
                diameter: 50,
                isGroup: room.isGroup
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(verbatim: title(for: room))
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    // 그룹은 제목 옆에 참여 인원수. 1:1은 둘뿐이라 넣지 않는다.
                    if room.isGroup, let count = memberCounts[room.id], count > 0 {
                        Text("\(count)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(verbatim: preview(for: room))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: timeText(for: room) ?? " ")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if let unread = unreadCounts[room.id], unread > 0 {
                    Text("\(unread)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(Color.accentColor))
                        .frame(height: Self.badgeHeight)
                } else {
                    Color.clear.frame(width: 1, height: Self.badgeHeight)
                }
            }
        }
        .padding(.vertical, 7)
    }

    /// 마지막 메시지 미리보기. 내가 보낸 것이면 "나: "를 앞에 붙인다.
    private func preview(for room: DevChatRoom) -> String {
        guard let last = lastMessages[room.id] else {
            return DevChatStrings.localized("아직 메시지가 없습니다", locale: locale)
        }
        let body: String
        if last.isDeleted {
            body = DevChatStrings.localized("삭제된 메시지", locale: locale)
        } else if !last.body.isEmpty {
            body = last.body.replacingOccurrences(of: "\n", with: " ")
        } else {
            switch last.messageType {
            case .image: body = DevChatStrings.localized("사진", locale: locale)
            case .file: body = last.attachmentName ?? DevChatStrings.localized("파일", locale: locale)
            case .text: body = ""
            }
        }
        guard last.senderId == profile.id else { return body }
        return "\(DevChatStrings.localized("나", locale: locale)): \(body)"
    }

    /// 오늘은 시각, 어제는 "어제", 그 이전은 월·일. 규칙은 `DevChatTimestamp`에 있다.
    private func timeText(for room: DevChatRoom) -> String? {
        guard let date = lastMessages[room.id]?.createdAt else { return nil }
        return DevChatTimestamp.listLabel(
            for: date, now: .now, calendar: calendar, locale: locale
        )
    }

    // MARK: - 데이터

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func title(for room: DevChatRoom) -> String {
        if let name = room.name, !name.isEmpty { return name }
        return resolvedTitles[room.id] ?? DevChatStrings.localized("대화", locale: locale)
    }

    private func refresh() async {
        guard let roomService else { return }
        do {
            try await roomService.loadRooms()
            lastMessages = try await roomService.lastMessages(for: roomService.rooms.map(\.id))
            unreadCounts = await roomService.unreadCounts()
            await resolveMembers(using: roomService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 1:1 방 제목(상대 이름)과 그룹 인원수를 채운다. 이미 받아둔 방은 다시 조회하지 않는다.
    private func resolveMembers(using roomService: DevChatRoomService) async {
        for room in roomService.rooms {
            let needsTitle = room.name == nil && resolvedTitles[room.id] == nil
            let needsCount = room.isGroup && memberCounts[room.id] == nil
            guard needsTitle || needsCount else { continue }
            guard let members = try? await roomService.members(of: room.id) else { continue }

            if needsCount { memberCounts[room.id] = members.count }
            if needsTitle {
                let other = members.first { $0.id != profile.id }
                resolvedTitles[room.id] = other?.displayName
                    ?? DevChatStrings.localized("대화", locale: locale)
            }
        }
    }
}
#endif
