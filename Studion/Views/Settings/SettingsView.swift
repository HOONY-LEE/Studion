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

    #if DEBUG
    /// 개발자 도구에서 샘플 문제집 개수를 세기 위한 것. 삭제 후 즉시 갱신되도록 `@Query`를 쓴다.
    @Query private var allQuestionSets: [QuestionSet]
    #endif

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
                #if DEBUG
                developerSection
                #endif
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

            // Sign in with Apple은 유료 멤버십 entitlement가 있어야 동작한다.
            // 없는 빌드에서는 버튼을 아예 노출하지 않는다 — 눌러도 실패할 항목을 두지 않는다.
            #if CLOUD_SYNC
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
            #endif
        } header: {
            Text("기기 간 데이터")
        } footer: {
            #if CLOUD_SYNC
            Text("""
                기기를 바꿔도 데이터를 유지하려면 같은 iCloud 계정을 쓰세요. \
                로그인하지 않아도 모든 기능은 이 기기에서 그대로 동작합니다. \
                저장된 내용은 본인의 iCloud에만 보관되며 개발자가 볼 수 없습니다.
                """)
            #else
            Text("""
                이 빌드에는 기기 간 동기화가 포함되어 있지 않습니다. \
                모든 기능은 그대로 동작하며 데이터는 이 기기에 저장됩니다. \
                기기를 옮길 때는 아래 백업 내보내기를 사용하세요.
                """)
            #endif
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

    // MARK: - 개발자 도구 (DEBUG 전용)

    #if DEBUG
    /// 개발 중 화면을 확인하기 위한 도구. 출시본에는 이 섹션이 아예 컴파일되지 않는다.
    ///
    /// 문구를 `Text(verbatim:)`으로 쓰는 이유: 개발자용이라 번역할 필요가 없고,
    /// String Catalog에 개발용 문자열이 섞여 들어가는 것을 막기 위함이다.
    private var developerSection: some View {
        Section {
            // 팀 내부 메신저. 탭바에 두면 학생이 쓰는 기능처럼 보여서 설정 안으로 옮겼다.
            // → docs/10-developer-chat.md
            NavigationLink {
                DeveloperChatView()
            } label: {
                Label {
                    Text(verbatim: "팀 메신저")
                } icon: {
                    Image(systemName: "message")
                }
            }

            Button {
                SampleDataSeeder.seedQuestionSets(into: context)
            } label: {
                Label {
                    Text(verbatim: "샘플 문제집 추가")
                } icon: {
                    Image(systemName: "wand.and.stars")
                }
            }

            if sampleSetCount > 0 {
                Button(role: .destructive) {
                    SampleDataSeeder.removeSampleQuestionSets(from: context)
                } label: {
                    Label {
                        Text(verbatim: "샘플 문제집 삭제 (\(sampleSetCount)개)")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
        } header: {
            Text(verbatim: "개발자 도구")
        } footer: {
            Text(verbatim: "이 섹션은 DEBUG 빌드에만 나타납니다. 학습 탭에 네 가지 문제 유형이 담긴 샘플 문제집 5개를 넣습니다.")
        }
    }

    private var sampleSetCount: Int {
        allQuestionSets.filter { $0.authorDisplayName == SampleDataSeeder.sampleMarker }.count
    }
    #endif

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
