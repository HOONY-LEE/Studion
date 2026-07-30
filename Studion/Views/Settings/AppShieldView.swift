import FamilyControls
import SwiftData
import SwiftUI

/// 집중 모드 설정 — 다른 앱 차단. `docs/09-app-shield.md`의 설계를 따른다.
///
/// 전체 끄기는 어떤 강도에서도 잠기지 않는다 (§5-3). 긴급 해제도 항상 보인다 (§5-2).
struct AppShieldView: View {
    @Environment(\.calendar) private var calendar

    @State private var store = AppShieldStore()
    @State private var isPickingApps = false

    @Query private var allPlanItems: [PlanItem]

    /// 오늘 할 일만 센다. 지난 할 일을 끌고 오지 않는다 (문서 §2-2).
    private var todaysItems: [PlanItem] {
        allPlanItems.filter { PlannerDateHelper.isSameDay($0.date, Date(), calendar: calendar) }
    }

    private var completedCount: Int { todaysItems.filter(\.isDone).count }
    private var totalCount: Int { todaysItems.count }

    var body: some View {
        Form {
            switch store.authorization {
            case .unknown:
                permissionSection
            case .unavailable(let reason):
                unavailableSection(reason)
            case .approved:
                shieldSections
            }
        }
        .navigationTitle("집중 모드")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $isPickingApps, selection: $store.selection)
        .task {
            if case .unknown = store.authorization {
                await store.requestAuthorization()
            }
        }
    }

    // MARK: - 권한

    private var permissionSection: some View {
        Section {
            ProgressView()
                .frame(maxWidth: .infinity)
        } footer: {
            Text("스크린 타임 권한을 확인하는 중입니다.")
        }
    }

    /// 권한이 없을 때. **왜 안 되는지와 무엇이 필요한지를 그대로 말한다** — 이 기능은
    /// 애플의 별도 승인이 있어야 동작하고, 그 사실을 숨기면 고장난 것처럼 보인다.
    private func unavailableSection(_ reason: String) -> some View {
        Section {
            Label {
                Text("아직 쓸 수 없어요")
            } icon: {
                Image(systemName: "lock.slash")
            }
            Button("다시 시도") {
                Task { await store.requestAuthorization() }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("앱 차단은 애플의 스크린 타임 권한(Family Controls)이 있어야 동작합니다. 이 권한은 애플에 따로 신청해 승인받아야 하며, 승인 전에는 켤 수 없습니다.")
                Text(verbatim: reason)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - 본 설정

    @ViewBuilder
    private var shieldSections: some View {
        Section {
            Button {
                isPickingApps = true
            } label: {
                LabeledContent {
                    Text(store.hasSelection ? "\(selectedCount)개" : "고르기")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("차단할 앱", systemImage: "app.badge.checkmark")
                }
            }
        } footer: {
            Text("전화·메시지·설정은 고르더라도 차단하지 않습니다. 급할 때 폰이 잠기면 안 되니까요.")
        }

        Section {
            Picker("강도", selection: $store.strength) {
                ForEach(FocusStrength.allCases) { level in
                    Text(verbatim: level.label).tag(level)
                }
            }
            .pickerStyle(.inline)
        } header: {
            Text("강도")
        } footer: {
            Text(verbatim: store.strength.explanation)
        }

        Section {
            Toggle("할 일을 채우면 자동 해제", isOn: $store.unlocksByTaskCompletion)

            if store.unlocksByTaskCompletion {
                // 퍼센트를 자유 입력받지 않고 10% 단위로 고르게 한다 — 미세 조정이 의미 없는 값이다.
                Picker("목표 완료율", selection: $store.requiredCompletionRate) {
                    ForEach([0.5, 0.6, 0.7, 0.8, 0.9, 1.0], id: \.self) { rate in
                        Text(verbatim: "\(Int(rate * 100))%").tag(rate)
                    }
                }
                LabeledContent("오늘 완료") {
                    Text(verbatim: "\(completedCount) / \(totalCount)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        } header: {
            Text("할 일 연동")
        } footer: {
            Text("오늘 할 일이 하나도 없으면 차단하지 않습니다. 한 번 풀리면 그날은 다시 잠기지 않습니다.")
        }

        Section {
            if store.isShielding {
                Button("집중 끝내기") {
                    store.stopShielding()
                }
            } else {
                Button("지금 집중 시작") {
                    store.startShielding()
                }
                .disabled(!store.hasSelection)
            }
        } header: {
            Text("집중")
        } footer: {
            if !store.hasSelection {
                Text("차단할 앱을 먼저 골라주세요.")
            } else if store.isShielding {
                Text("고른 앱이 지금 가려져 있습니다. 언제든 여기서 끝낼 수 있어요.")
            }
        }

        // 어떤 강도에서도 빠져나갈 수 있어야 한다. 해제해도 기록을 남기지 않는다.
        if store.isShielding {
            Section {
                Button("긴급 해제", role: .destructive) {
                    store.stopShielding()
                }
            } footer: {
                Text("바로 풀립니다. 이유를 묻지 않고, 기록도 남지 않아요.")
            }
        }
    }

    private var selectedCount: Int {
        store.selection.applicationTokens.count
            + store.selection.categoryTokens.count
            + store.selection.webDomainTokens.count
    }
}
