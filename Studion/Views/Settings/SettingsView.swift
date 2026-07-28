import SwiftUI
import SwiftData
import AuthenticationServices
import UniformTypeIdentifiers

/// 설정 탭.
struct SettingsView: View {
    @Environment(AppleSignInStore.self) private var signInStore
    @Environment(CloudAccountStatus.self) private var cloudStatus
    @Environment(\.modelContext) private var context

    @AppStorage(PreferenceKey.appearance) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(PreferenceKey.language) private var languageRaw = AppLanguage.system.rawValue

    @Query private var profiles: [AcademicProfile]

    @State private var isConfirmingSignOut = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument: BackupFile?
    @State private var pendingImport: BackupDocument?
    @State private var isChoosingRestoreMode = false
    @State private var errorMessage: String?

    private var profile: AcademicProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                syncSection
                appearanceSection
                academicSection
                subjectSection
                dataSection
            }
            .navigationTitle("설정")
            .onAppear(perform: ensureProfileExists)
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "studion-backup"
            ) { result in
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                handleImportResult(result)
            }
            .confirmationDialog(
                "백업을 어떻게 복원할까요?",
                isPresented: $isChoosingRestoreMode,
                titleVisibility: .visible
            ) {
                Button("기존 데이터 지우고 덮어쓰기", role: .destructive) { restore(mode: .replace) }
                Button("기존 데이터에 추가하기") { restore(mode: .merge) }
                Button("취소", role: .cancel) { pendingImport = nil }
            } message: {
                Text("덮어쓰기를 고르면 이 기기의 기존 기록이 모두 사라집니다.")
            }
            .alert("문제가 생겼어요", isPresented: .constant(errorMessage != nil)) {
                Button("확인") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 동기화

    @ViewBuilder
    private var syncSection: some View {
        Section {
            LabeledContent("동기화 상태") {
                Text(cloudStatus.state.summary)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }

            if signInStore.isSignedIn {
                LabeledContent("Apple 계정") {
                    Label("연결됨", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color("GoalAchieved"))
                }
                Button("연결 해제") { isConfirmingSignOut = true }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = []
                } onCompletion: { result in
                    if case .success(let authorization) = result {
                        signInStore.handleAuthorization(authorization)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .listRowInsets(EdgeInsets())
            }
        } header: {
            Text("기기 간 데이터")
        } footer: {
            Text("""
                기기를 바꿔도 데이터를 유지하려면 같은 iCloud 계정을 쓰세요. \
                로그인하지 않아도 모든 기능은 이 기기에서 그대로 동작합니다. \
                저장된 내용은 본인의 iCloud에만 보관되며 개발자가 볼 수 없습니다.
                """)
        }
        .confirmationDialog(
            "Apple 계정 연결을 해제할까요?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("연결 해제") { signInStore.signOut() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 기기의 데이터는 지워지지 않습니다.")
        }
    }

    // MARK: - 모양 / 언어

    private var appearanceSection: some View {
        Section("모양") {
            Picker("테마", selection: $appearanceRaw) {
                ForEach(AppAppearance.allCases) { item in
                    Text(item.displayName).tag(item.rawValue)
                }
            }
            Picker("언어", selection: $languageRaw) {
                ForEach(AppLanguage.allCases) { item in
                    Text(item.displayName).tag(item.rawValue)
                }
            }
        }
    }

    // MARK: - 학사 정보

    @ViewBuilder
    private var academicSection: some View {
        if let profile {
            Section {
                Picker("학년", selection: Binding(
                    get: { profile.gradeLevel },
                    set: { profile.gradeLevel = $0 }
                )) {
                    ForEach(1...3, id: \.self) { Text("고\($0)").tag($0) }
                }

                Picker("입학연도", selection: Binding(
                    get: { profile.admissionYear },
                    set: { updateAdmissionYear($0) }
                )) {
                    ForEach(2020...2030, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                }

                Picker("등급제", selection: Binding(
                    get: { profile.gradingSystemType },
                    set: { profile.gradingSystemType = $0 }
                )) {
                    ForEach(GradingSystemType.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text("학사 정보")
            } footer: {
                Text("입학연도에 맞는 등급제를 제안합니다. 직접 바꿀 수 있으며, 이미 만든 학기의 등급제는 그대로 유지됩니다.")
            }
        }
    }

    private var subjectSection: some View {
        Section {
            NavigationLink {
                EnrolledSubjectListView()
            } label: {
                Label("이수 과목 관리", systemImage: "list.bullet")
            }
            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label("알림", systemImage: "bell")
            }
        }
    }

    // MARK: - 데이터

    private var dataSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                Label("백업 내보내기", systemImage: "square.and.arrow.up")
            }

            Button {
                isImporting = true
            } label: {
                Label("백업 가져오기", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("데이터")
        } footer: {
            Text("성적·계획·오답노트가 JSON 파일로 저장됩니다. 오답노트 사진은 용량 때문에 포함되지 않습니다.")
        }
    }

    // MARK: - 동작

    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        context.insert(AcademicProfile())
    }

    /// 입학연도에 맞는 등급제를 **제안**한다. 이미 만든 학기에는 소급 적용하지 않는다.
    private func updateAdmissionYear(_ year: Int) {
        guard let profile else { return }
        profile.admissionYear = year
        profile.gradingSystemType = year >= 2025 ? .fiveTier : .nineTier
    }

    private func exportBackup() {
        do {
            let document = try BackupService.makeDocument(from: context, exportedAt: Date())
            let data = try BackupDocument.makeEncoder().encode(document)
            exportDocument = BackupFile(data: data)
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let document = try BackupDocument.makeDecoder().decode(BackupDocument.self, from: data)
            // 쓰기 전에 검증한다. 여기서 걸리면 기존 데이터는 손대지 않은 상태다.
            try document.validate()

            pendingImport = document
            isChoosingRestoreMode = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(mode: BackupService.RestoreMode) {
        guard let pendingImport else { return }
        do {
            try BackupService.restore(pendingImport, mode: mode, into: context)
        } catch {
            errorMessage = error.localizedDescription
        }
        self.pendingImport = nil
    }
}

/// `fileExporter`에 넘길 래퍼.
private struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
