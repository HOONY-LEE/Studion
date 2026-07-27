import SwiftUI
import SwiftData

@main
struct StudionApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([
            AcademicProfile.self,
            Semester.self,
            SchoolSubjectRecord.self,
            MockExamSession.self,
            MockExamSubjectRecord.self,
            WrongAnswerNote.self,
            TimetableEntry.self,
            PlanItem.self,
        ])
        // CloudKit 연결은 7단계에서 진행한다. 지금은 로컬 전용으로 두되
        // 스키마 자체는 옵셔널 관계 + 기본값 규칙을 지켜 CloudKit 호환 형태로 설계한다.
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
