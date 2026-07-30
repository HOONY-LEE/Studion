#if DEBUG
import SwiftUI
import Supabase

/// 대화 화면. 애플 메시지를 따라간다 — 연달아 보낸 메시지는 붙여 묶고 마지막에만
/// 꼬리를 달며, 시간이 벌어지면 그 사이에 시각을 넣는다. 배치 규칙은 `DevChatLayout`.
struct DevChatRoomView: View {
    let client: SupabaseClient
    let room: DevChatRoom
    let title: String
    let profile: DevProfile

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    @State private var messageService: DevChatMessageService?
    @State private var draft = ""
    @State private var errorMessage: String?
    /// 그룹 대화에서 말풍선 위에 보낸 사람 이름을 붙이기 위한 이름표.
    @State private var memberNames: [UUID: String] = [:]

    private var rows: [DevChatLayout.Row] {
        DevChatLayout.rows(for: messageService?.messages ?? [])
    }

    var body: some View {
        transcript
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // 대화 중에는 탭바를 감춘다 — 애플 메시지도 대화에 들어가면 아래가 비고,
            // 입력창이 화면 맨 아래를 차지해야 한다.
            .toolbar(.hidden, for: .tabBar)
            .task { await start() }
            .onDisappear { messageService?.stopListening() }
            .alert("문제가 발생했어요", isPresented: errorAlertBinding) {
                Button("확인") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
    }

    // MARK: - 대화 본문

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        if let separator = row.timeSeparator {
                            timeSeparator(separator)
                        }
                        messageRow(row)
                            .id(row.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            // 대화는 항상 최신이 아래다. 처음 열 때도 맨 아래에서 시작한다.
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: rows.last?.id) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .bottom)
                }
            }
            .overlay {
                if rows.isEmpty {
                    Text("첫 메시지를 보내보세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func timeSeparator(_ date: Date) -> some View {
        Text(verbatim: DevChatTimestamp.separatorLabel(
            for: date, now: .now, calendar: calendar, locale: locale
        ))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    /// 말풍선 한 줄. 묶음 안에서는 2pt, 묶음이 끝나면 8pt 띄운다.
    private func messageRow(_ row: DevChatLayout.Row) -> some View {
        let isMine = row.message.senderId == profile.id

        return VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if room.isGroup, !isMine, row.isGroupHead {
                Text(verbatim: memberNames[row.message.senderId] ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, groupAvatarInset + 14)
            }

            HStack(alignment: .bottom, spacing: 6) {
                if isMine { Spacer(minLength: 44) }

                // 그룹 대화에서만 받은 메시지 옆에 아바타를 둔다. 묶음의 마지막 줄에만
                // 보이고 나머지 줄은 같은 폭을 비워 말풍선 왼쪽을 맞춘다.
                if room.isGroup, !isMine {
                    if row.isGroupTail {
                        DevChatAvatar(
                            displayName: memberNames[row.message.senderId] ?? "",
                            diameter: groupAvatarDiameter
                        )
                    } else {
                        Spacer().frame(width: groupAvatarDiameter)
                    }
                }

                DevChatBubble(
                    text: row.message.body,
                    isMine: isMine,
                    hasTail: row.isGroupTail
                )

                if !isMine { Spacer(minLength: 44) }
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .padding(.bottom, row.isGroupTail ? 8 : 2)
    }

    private var groupAvatarDiameter: CGFloat { 28 }
    private var groupAvatarInset: CGFloat { groupAvatarDiameter + 6 }

    // MARK: - 입력창

    /// 애플 메시지처럼 테두리만 있는 캡슐 안에 입력과 전송 버튼을 함께 둔다.
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 6) {
            TextField("메시지", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.leading, 14)
                .padding(.vertical, 7)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(canSend ? Color.accentColor : Color(.systemGray3), in: Circle())
            }
            .disabled(!canSend)
            .padding(.trailing, 4)
            .padding(.bottom, 3)
            .accessibilityLabel("보내기")
        }
        .background {
            Capsule(style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var canSend: Bool { !draft.trimmed.isEmpty }

    // MARK: - 동작

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func start() async {
        if messageService == nil {
            messageService = DevChatMessageService(client: client)
        }
        guard let messageService else { return }

        do {
            try await messageService.loadMessages(roomID: room.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        if room.isGroup, memberNames.isEmpty {
            let roomService = DevChatRoomService(client: client)
            if let members = try? await roomService.members(of: room.id) {
                memberNames = Dictionary(
                    uniqueKeysWithValues: members.map { ($0.id, $0.displayName) }
                )
            }
        }

        await messageService.startListening(roomID: room.id)
    }

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        draft = ""
        Task {
            do {
                try await messageService?.send(body: text, roomID: room.id, senderID: profile.id)
            } catch {
                errorMessage = error.localizedDescription
                // 실패한 글을 잃지 않도록 되돌려 준다.
                draft = text
            }
        }
    }
}
#endif
