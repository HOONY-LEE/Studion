#if DEBUG
import SwiftUI
import Supabase

/// 대화 화면. 애플 메시지처럼 내 메시지는 오른쪽(accent), 상대 메시지는 왼쪽(중립 배경)에 둔다.
struct DevChatRoomView: View {
    let client: SupabaseClient
    let room: DevChatRoom
    let title: String
    let profile: DevProfile

    @State private var messageService: DevChatMessageService?
    @State private var draft = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messageService?.messages ?? []) { message in
                            bubble(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .onChange(of: messageService?.messages.count) {
                    guard let lastID = messageService?.messages.last?.id else { return }
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextField("메시지", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(draft.trimmed.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if messageService == nil {
                messageService = DevChatMessageService(client: client)
            }
            guard let messageService else { return }
            do {
                try await messageService.loadMessages(roomID: room.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            await messageService.startListening(roomID: room.id)
        }
        .onDisappear {
            messageService?.stopListening()
        }
        .alert("문제가 발생했어요", isPresented: errorAlertBinding) {
            Button("확인") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    @ViewBuilder
    private func bubble(for message: DevMessage) -> some View {
        let isMine = message.senderId == profile.id
        HStack {
            if isMine { Spacer(minLength: 40) }
            Text(verbatim: message.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isMine ? Color.accentColor : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(isMine ? Color.white : Color.primary)
            if !isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
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
                draft = text
            }
        }
    }
}
#endif
