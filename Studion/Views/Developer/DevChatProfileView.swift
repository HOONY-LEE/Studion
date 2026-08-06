import SwiftUI
import PhotosUI
import Supabase

/// 내 프로필 — 사진과 표시 이름을 바꾼다.
///
/// Apple 로그인은 이름을 최초 한 번만 내려주므로, 그 기회를 놓친 사람은 여기서 처음으로
/// 자기 이름을 정하게 된다. 그래서 **이름을 비워둔 채로 저장할 수 없게** 한다 —
/// 팀원 목록에서 누가 누군지 알 수 없게 되기 때문이다.
struct DevChatProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let client: SupabaseClient
    let profile: DevProfile
    /// 저장이 끝나면 바뀐 프로필을 위로 올린다 — 대화 목록이 곧바로 새 이름·사진을 쓴다.
    let onUpdated: (DevProfile) -> Void

    @State private var displayName = ""
    @State private var avatarPath: String?
    /// 방금 고른 사진. 올리기 전에도 화면에 바로 보여준다.
    @State private var pickedImageData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var service: DevChatProfileService { DevChatProfileService(client: client) }

    private var canSave: Bool {
        !displayName.trimmed.isEmpty && !isSaving
    }

    private var hasAvatar: Bool {
        pickedImageData != nil || (avatarPath?.isEmpty == false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        avatarPreview

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(hasAvatar ? "사진 바꾸기" : "사진 추가")
                        }

                        if hasAvatar {
                            Button("사진 지우기", role: .destructive) {
                                pickedImageData = nil
                                avatarPath = nil
                            }
                            .font(.footnote)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("이름", text: $displayName)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("표시 이름")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                    } else {
                        Text("팀원 목록과 대화방에 이 이름으로 보입니다.")
                    }
                }
            }
            .navigationTitle("내 프로필")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("저장") { save() }
                            .disabled(!canSave)
                    }
                }
            }
            .onAppear {
                displayName = profile.displayName
                avatarPath = profile.avatarPath
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let raw = try? await item.loadTransferable(type: Data.self) {
                        // 오답노트 사진과 같은 방식으로 올리기 전에 용량을 줄인다.
                        pickedImageData = ImageDownsampler.downsample(raw, maxPixelSize: 512)
                    }
                    photoItem = nil
                }
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let pickedImageData, let image = UIImage(data: pickedImageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
        } else {
            DevChatAvatar(
                displayName: displayName,
                diameter: 96,
                avatarPath: avatarPath,
                client: client
            )
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                let name = displayName.trimmed
                try await service.updateDisplayName(name, userID: profile.id)

                var newPath = avatarPath
                if let pickedImageData {
                    newPath = try await service.uploadAvatar(pickedImageData, userID: profile.id)
                } else if avatarPath == nil, profile.avatarPath != nil {
                    // 사진을 지운 경우.
                    try await service.removeAvatar(userID: profile.id)
                }

                var updated = profile
                updated.displayName = name
                updated.avatarPath = newPath
                onUpdated(updated)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
