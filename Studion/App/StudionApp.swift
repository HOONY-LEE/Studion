import SwiftUI
import SwiftData

@main
struct StudionApp: App {
    @State private var signInStore = AppleSignInStore()
    @State private var cloudStatus = CloudAccountStatus()

    let modelContainer: ModelContainer = Self.makeModelContainer()

    @AppStorage(PreferenceKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            // 온보딩 게이트는 이 한 곳에만 둔다.
            Group {
                if hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .environment(signInStore)
            .environment(cloudStatus)
            .task {
                await cloudStatus.refresh()
                await signInStore.refreshCredentialState()
            }
        }
        .modelContainer(modelContainer)
    }

    private static let schema = Schema([
        AcademicProfile.self,
        Semester.self,
        SchoolSubjectRecord.self,
        MockExamSession.self,
        MockExamSubjectRecord.self,
        WrongAnswerNote.self,
        TimetableEntry.self,
        PlanItem.self,
    ])

    /// 컨테이너를 **항상 CloudKit으로 구성**한다.
    ///
    /// SwiftData는 런타임에 CloudKit을 켜고 끄는 API를 제공하지 않는다.
    /// iCloud 계정이 없는 기기에서는 동기화가 자연스럽게 비활성화되고 로컬 저장소로만 동작하므로,
    /// 로그인하지 않은 사용자도 모든 기능을 그대로 쓸 수 있다.
    private static func makeModelContainer() -> ModelContainer {
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.studion.app")
        )

        if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
            return container
        }

        // CloudKit 구성에 실패해도 앱이 죽지 않아야 한다 (원칙 2: 로컬 우선).
        // 개발 중 entitlement가 없거나 컨테이너를 만들 수 없는 환경에서 여기로 떨어진다.
        let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
            return container
        }

        // 로컬 저장소조차 열 수 없으면 데이터를 다룰 방법이 없다.
        // 조용히 빈 상태로 진행하면 사용자 데이터를 덮어쓸 위험이 있으므로 여기서 중단한다.
        fatalError("저장소를 열 수 없습니다. 기기 저장 공간을 확인해 주세요.")
    }
}
