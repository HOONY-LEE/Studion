#if DEBUG
import SwiftUI

/// 리액션 상세 — 이모지별로 누가 남겼는지 보여준다. WorkChat `ReactionDetailSheet`와 같다.
struct DevChatReactionDetailSheet: View {
    let summaries: [DevReactionSummary]
    /// 사용자 id → 표시 이름. 방 멤버 목록에서 만든다.
    let names: [UUID: String]
    let myID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            Group {
                if summaries.isEmpty {
                    ContentUnavailableView("아직 리액션이 없어요", systemImage: "face.smiling")
                } else {
                    List {
                        ForEach(summaries) { summary in
                            Section {
                                ForEach(summary.userIDs, id: \.self) { userID in
                                    HStack(spacing: 12) {
                                        DevChatAvatar(displayName: name(for: userID), diameter: 40)
                                        Text(verbatim: name(for: userID))
                                        Spacer(minLength: 0)
                                        if userID == myID {
                                            Text("나")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } header: {
                                Text(verbatim: "\(summary.emoji)  \(summary.count)")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("리액션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func name(for userID: UUID) -> String {
        if let known = names[userID] { return known }
        return DevChatStrings.localized("(이름 없음)", locale: locale)
    }
}
#endif
