#if DEBUG
import SwiftUI
import PhotosUI
import Supabase
import UIKit

/// 대화 화면. WorkChat iOS `MessageView`와 같은 구성이다 —
/// 비대칭 모서리 말풍선, 받은 쪽 아바타·이름, 모든 말풍선에 시각, 날짜 구분선,
/// 말풍선 아래 리액션 알약, 사진 앨범 그리드, 답장/수정/삭제 컨텍스트 메뉴, 첨부 시트.
///
/// 배치 규칙은 `DevChatLayout`이 정한다 — 뷰는 그 결과만 그린다.
struct DevChatRoomView: View {
    let client: SupabaseClient
    let room: DevChatRoom
    let title: String
    let profile: DevProfile

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    @State private var messageService: DevChatMessageService?
    @State private var draft = ""
    @State private var sending = false
    @State private var errorMessage: String?
    /// 그룹 대화에서 말풍선 위에 보낸 사람 이름을 붙이기 위한 이름표.
    @State private var memberNames: [UUID: String] = [:]

    @State private var replyingTo: DevMessage?
    @State private var editingMessage: DevMessage?
    @State private var deleteTarget: DevMessage?
    @State private var reactionDetailTarget: DevMessage?

    // 첨부 — 시트에서 고른 동작은 시트가 닫힌 뒤 여기서 띄운다(중첩 프레젠테이션 회피).
    @State private var showAttachSheet = false
    @State private var pendingPick: PickKind?
    @State private var showAlbumPicker = false
    @State private var albumItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var showCamera = false

    @FocusState private var composerFocused: Bool

    private enum PickKind { case album, file, camera }

    private var messages: [DevMessage] { messageService?.messages ?? [] }
    private var rows: [DevChatLayout.Row] {
        DevChatLayout.rows(for: messages, calendar: calendar)
    }

    var body: some View {
        transcript
            .safeAreaInset(edge: .top, spacing: 0) { realtimeBanner }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // 대화 중에는 탭바를 감춘다 — 입력창이 화면 맨 아래를 차지해야 한다.
            .toolbar(.hidden, for: .tabBar)
            .task { await start() }
            .onDisappear { messageService?.stopListening() }
            .alert("메시지를 삭제할까요?", isPresented: deleteAlertBinding) {
                Button("삭제", role: .destructive) {
                    if let target = deleteTarget { Task { await performDelete(target) } }
                    deleteTarget = nil
                }
                Button("취소", role: .cancel) { deleteTarget = nil }
            } message: {
                Text("삭제한 메시지는 되돌릴 수 없어요.")
            }
            .alert("문제가 발생했어요", isPresented: errorAlertBinding) {
                Button("확인") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: reactionSheetBinding) {
                DevChatReactionDetailSheet(
                    summaries: reactionDetailTarget.flatMap { messageService?.reactions[$0.id] } ?? [],
                    names: memberNames,
                    myID: profile.id
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAttachSheet, onDismiss: presentPendingPicker) {
                DevChatAttachmentSheet(
                    onSendPhotos: { datas in Task { await sendImages(datas) } },
                    onChooseAlbum: { pendingPick = .album },
                    onChooseFile: { pendingPick = .file },
                    onChooseCamera: { pendingPick = .camera }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .photosPicker(isPresented: $showAlbumPicker, selection: $albumItems,
                          maxSelectionCount: nil, matching: .images)
            .onChange(of: albumItems) { _, items in
                guard !items.isEmpty else { return }
                let picked = items
                albumItems = []
                Task { await sendAlbumItems(picked) }
            }
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first { sendPickedFile(url) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                DevChatCameraPicker { image in
                    guard let data = image.jpegData(compressionQuality: 0.9) else { return }
                    Task { await sendImages([data]) }
                }
                .ignoresSafeArea()
            }
    }

    // MARK: - 대화 본문

    private var transcript: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(rows) { row in
                            if let date = row.dateSeparator {
                                DevChatDateDivider(date: date)
                                    .padding(.vertical, 8)
                            }
                            messageRow(row, containerWidth: outer.size.width)
                                .padding(.top, row.showsSender ? 6 : 1)
                                .id(row.id)
                        }
                        // 스크롤 목적지. LazyVStack에서 아직 만들어지지 않은 행 id로 스크롤하면
                        // 추정 위치로 가버리므로 항상 이 마커를 겨냥한다.
                        Color.clear.frame(height: 1).id(Self.bottomMarker)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    // 대화가 짧아 뷰포트를 못 채울 때 콘텐츠가 아래로 붙어 위가 비는 것을 막는다.
                    .frame(minHeight: outer.size.height, alignment: .top)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                // 아무 데나 탭하면 키보드를 내린다. simultaneousGesture라 말풍선의 탭·롱프레스를
                // 가로채지 않는다.
                .simultaneousGesture(TapGesture().onEnded { composerFocused = false })
                .onChange(of: messages.last?.id) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(Self.bottomMarker, anchor: .bottom)
                    }
                }
                .overlay {
                    if messages.isEmpty { emptyConversation }
                }
            }
        }
    }

    private static let bottomMarker = "dev-chat-bottom"

    /// 실시간 구독이 실패했음을 알리는 띠.
    ///
    /// 이게 없으면 상대 메시지가 안 오는 상황이 "조용한 방"과 똑같이 보인다 — 내가 보낸
    /// 것은 (돌려받은 행을 바로 붙이므로) 잘 나타나서 더 헷갈린다.
    @ViewBuilder
    private var realtimeBanner: some View {
        if let failure = messageService?.realtimeFailure {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                VStack(alignment: .leading, spacing: 1) {
                    Text("실시간 수신이 연결되지 않았어요")
                        .font(.caption.bold())
                    Text("새 메시지를 받으려면 방을 다시 열어주세요.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
            .accessibilityHint(Text(verbatim: failure))
        }
    }

    /// 아직 대화가 없는 방의 빈 상태 — WorkChat과 같은 종이비행기 안내.
    private var emptyConversation: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.16), Color.accentColor.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 104, height: 104)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .rotationEffect(.degrees(-15))
                    .offset(x: 3, y: -1)
            }
            VStack(spacing: 7) {
                Text("대화를 시작해 보세요")
                    .font(.title3.weight(.bold))
                Text("첫 메시지를 보내면 여기에 표시돼요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 48)
    }

    // MARK: - 한 행

    @ViewBuilder
    private func messageRow(_ row: DevChatLayout.Row, containerWidth: CGFloat) -> some View {
        let message = row.first
        let mine = message.senderId == profile.id

        switch row.content {
        case .photoGroup(let group):
            // 앨범은 컨텍스트 메뉴를 달지 않는다 — 어느 사진에 대한 동작인지 애매해진다.
            // 사진 하나에 리액션을 남기고 싶으면 한 장씩 보내면 된다(1장은 앨범이 아니다).
            rowShell(row: row, isMine: mine, containerWidth: containerWidth) { width in
                DevChatPhotoGrid(messages: group, client: client, maxWidth: width)
            }
        case .single(let single):
            rowShell(row: row, isMine: mine, containerWidth: containerWidth) { width in
                bubbleStack(single, isMine: mine, photoWidth: width)
            }
            .contextMenu { contextMenu(for: single, isMine: mine) }
        }
    }

    /// 아바타·이름·시각을 배치하는 공통 껍데기. 내 메시지는 오른쪽, 받은 메시지는 왼쪽에
    /// 아바타를 두고 이름을 위에 올린다.
    @ViewBuilder
    private func rowShell<Content: View>(
        row: DevChatLayout.Row,
        isMine: Bool,
        containerWidth: CGFloat,
        @ViewBuilder content: (CGFloat) -> Content
    ) -> some View {
        // 말풍선과 같은 좌우 여백이 남도록 컨테이너 폭에서 시각칸(받은 쪽은 아바타까지) 뺀다.
        let photoWidth = min(300, max(150, containerWidth - (isMine ? 104 : 150)))
        let time = timeText(row.last.createdAt)

        if isMine {
            // 말풍선 자체에 폭 제한을 두지 않고 Spacer(minLength:)로만 최대폭을 잡는다 —
            // 안쪽에 .frame(maxWidth:)를 더하면 바깥 trailing 정렬과 겹쳐 hugging이 깨진다.
            HStack(alignment: .bottom, spacing: 4) {
                Spacer(minLength: 24)
                // .fixedSize()로 시각을 항상 한 줄로 — 넓은 사진 옆에서 칸이 눌리면
                // "오전 11:18"이 세로로 접힌다.
                Text(verbatim: time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                content(photoWidth)
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                if row.showsSender {
                    DevChatAvatar(displayName: senderName(row.first), diameter: 34)
                } else {
                    Color.clear.frame(width: 34, height: 1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if row.showsSender, room.isGroup {
                        Text(verbatim: senderName(row.first))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .bottom, spacing: 4) {
                        content(photoWidth)
                        Text(verbatim: time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                Spacer(minLength: 24)
            }
        }
    }

    /// 말풍선 + 리액션 알약 + "수정됨".
    @ViewBuilder
    private func bubbleStack(_ message: DevMessage, isMine: Bool, photoWidth: CGFloat) -> some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
            bubble(message, isMine: isMine, photoWidth: photoWidth)
            reactionsRow(message)
            if message.editedAt != nil, !message.isDeleted {
                Text("수정됨")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: DevMessage, isMine: Bool, photoWidth: CGFloat) -> some View {
        if message.hasImage {
            // 답장이 달려 앨범으로 묶이지 못한 단일 사진도 같은 컴포넌트로 그려서 탭하면
            // 전체화면 뷰어가 뜨도록 통일한다.
            DevChatPhotoGrid(messages: [message], client: client, maxWidth: photoWidth)
        } else if !message.isDeleted, message.messageType == .file {
            fileBubble(message, isMine: isMine)
        } else {
            textBubble(message, isMine: isMine)
        }
    }

    private func textBubble(_ message: DevMessage, isMine: Bool) -> some View {
        let foreground = devChatBubbleForeground(isMine: isMine, isDeleted: message.isDeleted)

        return VStack(alignment: .leading, spacing: 6) {
            // 답장이면 "OO에게 답장" + 원문 미리보기를 본문과 한 말풍선에 합친다.
            if let replyID = message.replyToId, !message.isDeleted, let quoted = findMessage(replyID) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(senderName(quoted))에게 답장")
                        .font(.caption.bold())
                        .foregroundStyle(isMine ? AnyShapeStyle(.white.opacity(0.9)) : AnyShapeStyle(.secondary))
                    Text(verbatim: quotePreview(quoted))
                        .font(.caption)
                        .foregroundStyle(isMine ? AnyShapeStyle(.white.opacity(0.7)) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
            Text(verbatim: message.isDeleted ? deletedLabel : message.body)
                .foregroundStyle(foreground)
                .italic(message.isDeleted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(devChatBubbleBackground(isMine: isMine, isDeleted: message.isDeleted))
        .clipShape(.rect(cornerRadii: devChatBubbleCorners(isMine: isMine)))
    }

    private func fileBubble(_ message: DevMessage, isMine: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundStyle(isMine ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: message.attachmentName ?? "파일")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isMine ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                if let size = message.attachmentSize {
                    Text(verbatim: ByteCountFormatter.string(
                        fromByteCount: Int64(size), countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(isMine
                            ? AnyShapeStyle(Color.white.opacity(0.85)) : AnyShapeStyle(.secondary))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 320, alignment: .leading)
        .background(devChatBubbleBackground(isMine: isMine, isDeleted: false))
        .clipShape(.rect(cornerRadii: devChatBubbleCorners(isMine: isMine)))
    }

    /// 말풍선 아래 리액션 알약들. 탭하면 토글, 맨 끝 버튼으로 다른 이모지를 추가한다.
    @ViewBuilder
    private func reactionsRow(_ message: DevMessage) -> some View {
        let summaries = messageService?.reactions[message.id] ?? []
        if !summaries.isEmpty {
            HStack(spacing: 6) {
                ForEach(summaries) { summary in
                    Button {
                        Task { await messageService?.toggleReaction(message, emoji: summary.emoji) }
                    } label: {
                        HStack(spacing: 4) {
                            Text(verbatim: summary.emoji).font(.system(size: 13))
                            Text("\(summary.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(summary.reactedByMe ? Color.accentColor : .secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(summary.reactedByMe
                            ? Color.accentColor.opacity(0.15)
                            : Color(.secondarySystemBackground)))
                        .overlay(Capsule().strokeBorder(
                            summary.reactedByMe ? Color.accentColor : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                // 알약을 모르는 사람도 리액션을 더 달 수 있게 하는 버튼.
                Menu {
                    ForEach(DevChatMessageService.quickReactionEmojis, id: \.self) { emoji in
                        Button(emoji) {
                            Task { await messageService?.toggleReaction(message, emoji: emoji) }
                        }
                    }
                    Divider()
                    Button {
                        reactionDetailTarget = message
                    } label: {
                        Label("리액션 남긴 사람", systemImage: "person.2")
                    }
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for message: DevMessage, isMine: Bool) -> some View {
        if !message.isDeleted {
            Menu {
                ForEach(DevChatMessageService.quickReactionEmojis, id: \.self) { emoji in
                    Button(emoji) {
                        Task { await messageService?.toggleReaction(message, emoji: emoji) }
                    }
                }
            } label: {
                Label("리액션", systemImage: "face.smiling")
            }

            if !(messageService?.reactions[message.id] ?? []).isEmpty {
                Button { reactionDetailTarget = message } label: {
                    Label("리액션 남긴 사람", systemImage: "person.2")
                }
            }

            Button {
                replyingTo = message
                editingMessage = nil
                composerFocused = true
            } label: {
                Label("답장", systemImage: "arrowshape.turn.up.left")
            }

            if !message.body.isEmpty {
                Button {
                    UIPasteboard.general.string = message.body
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("복사", systemImage: "doc.on.doc")
                }
            }

            if isMine, message.messageType == .text {
                Button {
                    editingMessage = message
                    replyingTo = nil
                    draft = message.body
                    composerFocused = true
                } label: {
                    Label("수정", systemImage: "pencil")
                }
            }

            if isMine {
                Button(role: .destructive) { deleteTarget = message } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - 입력창

    private var composer: some View {
        VStack(spacing: 0) {
            if let editingMessage {
                composerBanner(
                    tint: .orange,
                    title: Text("메시지 수정"),
                    preview: editingMessage.body
                ) {
                    self.editingMessage = nil
                    draft = ""
                }
            } else if let replyingTo {
                composerBanner(
                    tint: .accentColor,
                    title: Text("\(senderName(replyingTo))에게 답장"),
                    preview: quotePreview(replyingTo)
                ) {
                    self.replyingTo = nil
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                Button { showAttachSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("첨부")

                HStack(spacing: 0) {
                    TextField("메시지 입력", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($composerFocused)
                        .padding(.leading, 14)
                        .padding(.trailing, 4)
                        .padding(.vertical, 9)
                    sendButton
                        .padding(.trailing, 5)
                        .padding(.bottom, 2)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func composerBanner(
        tint: Color, title: Text, preview: String, onCancel: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                title.font(.caption).foregroundStyle(tint)
                Text(verbatim: preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("취소")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private var sendButton: some View {
        let canSend = !draft.trimmed.isEmpty && !sending

        return Button {
            Task { await submit() }
        } label: {
            // 원과 화살표를 따로 그린다 — arrow.up.circle.fill의 화살표는 뚫린 구멍이라
            // 뒤의 반투명 재질이 비쳐 다크모드에서 흐릿해진다.
            ZStack {
                Circle().fill(canSend ? Color.accentColor : Color(.systemGray3))
                Image(systemName: editingMessage == nil ? "arrow.up" : "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
            // 보이는 원은 30pt, 탭 영역만 넓힌다.
            .frame(width: 44, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel(editingMessage == nil ? "보내기" : "저장")
    }

    // MARK: - 동작

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }

    private var reactionSheetBinding: Binding<Bool> {
        Binding(get: { reactionDetailTarget != nil }, set: { if !$0 { reactionDetailTarget = nil } })
    }

    private var deletedLabel: String {
        DevChatStrings.localized("삭제된 메시지", locale: locale)
    }

    private func findMessage(_ id: UUID) -> DevMessage? {
        messages.first { $0.id == id }
    }

    private func senderName(_ message: DevMessage) -> String {
        if message.senderId == profile.id {
            return DevChatStrings.localized("나", locale: locale)
        }
        return memberNames[message.senderId] ?? title
    }

    /// 인용에 보여줄 한 줄. 사진·파일은 본문이 없으니 종류를 대신 보여준다.
    private func quotePreview(_ message: DevMessage) -> String {
        if message.isDeleted { return deletedLabel }
        if !message.body.isEmpty { return message.body }
        switch message.messageType {
        case .image: return DevChatStrings.localized("사진", locale: locale)
        case .file: return message.attachmentName ?? DevChatStrings.localized("파일", locale: locale)
        case .text: return ""
        }
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    private func start() async {
        if messageService == nil {
            messageService = DevChatMessageService(client: client, myID: profile.id)
        }
        guard let messageService else { return }

        do {
            try await messageService.loadMessages(roomID: room.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        // 이름표는 1:1에서도 필요하다 — 답장 인용에 상대 이름을 보여줘야 한다.
        if memberNames.isEmpty {
            let roomService = DevChatRoomService(client: client)
            if let members = try? await roomService.members(of: room.id) {
                memberNames = Dictionary(
                    uniqueKeysWithValues: members.map { ($0.id, $0.displayName) }
                )
            }
        }

        // 방을 나가도 읽음 처리가 끊기지 않도록 뷰 생명주기와 분리한다.
        Task { await messageService.markRead(roomID: room.id) }
        await messageService.startListening(roomID: room.id)
    }

    private func submit() async {
        let text = draft.trimmed
        guard !text.isEmpty, let messageService else { return }
        sending = true
        defer { sending = false }

        do {
            if let editing = editingMessage {
                try await messageService.edit(editing, newBody: text)
                editingMessage = nil
            } else {
                try await messageService.send(
                    body: text, roomID: room.id, replyToID: replyingTo?.id
                )
                replyingTo = nil
            }
            draft = ""
        } catch {
            // 실패한 글을 잃지 않도록 입력창은 그대로 둔다.
            errorMessage = error.localizedDescription
        }
    }

    private func performDelete(_ message: DevMessage) async {
        do {
            try await messageService?.delete(message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 첨부

    /// 시트가 닫힌 뒤 고른 동작에 해당하는 피커를 띄운다.
    private func presentPendingPicker() {
        guard let pick = pendingPick else { return }
        pendingPick = nil
        switch pick {
        case .album: showAlbumPicker = true
        case .file: showFileImporter = true
        case .camera:
            if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
        }
    }

    private func sendAlbumItems(_ items: [PhotosPickerItem]) async {
        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) { datas.append(data) }
        }
        await sendImages(datas)
    }

    private func sendImages(_ datas: [Data]) async {
        guard let messageService else { return }
        sending = true
        defer { sending = false }
        for data in datas {
            do {
                try await messageService.sendAttachment(
                    data: data, fileName: "photo.jpg", mimeType: "image/jpeg",
                    type: .image, roomID: room.id
                )
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
    }

    private func sendPickedFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let name = url.lastPathComponent

        Task {
            guard let messageService else { return }
            sending = true
            defer { sending = false }
            do {
                try await messageService.sendAttachment(
                    data: data, fileName: name, mimeType: "application/octet-stream",
                    type: .file, roomID: room.id
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// 날짜 구분선 — 가운데 알약. WorkChat `DateDivider`와 같다.
struct DevChatDateDivider: View {
    let date: Date

    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: date.formatted(
            .dateTime.year().month().day().weekday(.wide).locale(locale)))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
            .frame(maxWidth: .infinity)
    }
}
#endif
