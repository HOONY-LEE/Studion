import SwiftUI
import SwiftData

/// 최초 실행 온보딩.
///
/// **로그인 단계를 포함하지 않는다.** 동기화는 나중에 설정에서 선택할 일이고,
/// 앱을 처음 켠 사람에게 먼저 물을 것이 아니다.
///
/// 모든 단계는 건너뛸 수 있으며, 건너뛴 값은 나중에 설정에서 채울 수 있다.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @AppStorage(PreferenceKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    @Query private var profiles: [AcademicProfile]

    @State private var step = 0
    @State private var admissionYear = 2025
    @State private var gradeLevel = 1
    @State private var gradingSystem: GradingSystemType = .fiveTier
    @State private var isAddingTimetable = false

    private let lastStep = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    academicStep.tag(0)
                    subjectStep.tag(1)
                    timetableStep.tag(2)
                    doneStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                footer
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if step < lastStep {
                        Button("건너뛰기") { finish() }
                    }
                }
            }
        }
    }

    // MARK: - 단계

    private var academicStep: some View {
        stepScaffold(
            icon: "graduationcap",
            title: "학년을 알려주세요",
            message: "입학연도에 맞는 등급제를 제안해 드립니다. 나중에 설정에서 바꿀 수 있어요."
        ) {
            Form {
                Picker("학년", selection: $gradeLevel) {
                    ForEach(1...3, id: \.self) { Text("고\($0)").tag($0) }
                }
                Picker("입학연도", selection: $admissionYear) {
                    ForEach(2020...2030, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                }
                Picker("등급제", selection: $gradingSystem) {
                    ForEach(GradingSystemType.allCases) { Text($0.displayName).tag($0) }
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: admissionYear) { _, year in
                gradingSystem = year >= 2025 ? .fiveTier : .nineTier
            }
        }
    }

    private var subjectStep: some View {
        stepScaffold(
            icon: "book.closed",
            title: "이수 과목은 나중에",
            message: "성적 탭에서 학기를 만들고 과목을 추가하면 됩니다. 지금 정하지 않아도 괜찮아요."
        ) { EmptyView() }
    }

    private var timetableStep: some View {
        stepScaffold(
            icon: "calendar.badge.plus",
            title: "시간표를 등록할까요?",
            message: "학교와 학원 일정을 넣어두면 플래너에서 하루가 한눈에 보입니다."
        ) {
            Button("시간표 추가") { isAddingTimetable = true }
                .buttonStyle(.borderedProminent)
                .sheet(isPresented: $isAddingTimetable) { TimetableFormView() }
        }
    }

    private var doneStep: some View {
        stepScaffold(
            icon: "checkmark.circle",
            title: "준비됐어요",
            message: "비워둔 항목은 언제든 설정에서 채울 수 있습니다."
        ) { EmptyView() }
    }

    // MARK: - 공통

    private func stepScaffold<Content: View>(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            content()

            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        Button(step == lastStep ? "시작하기" : "다음") {
            if step == lastStep {
                finish()
            } else {
                withAnimation { step += 1 }
            }
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding()
    }

    private func finish() {
        // 건너뛰어도 입력한 값까지는 저장한다.
        let profile = profiles.first ?? {
            let created = AcademicProfile()
            context.insert(created)
            return created
        }()

        profile.admissionYear = admissionYear
        profile.gradeLevel = gradeLevel
        profile.gradingSystemType = gradingSystem

        hasCompletedOnboarding = true
    }
}
