import SwiftUI
import SwiftData

/// 모의고사 서브탭. 회차 리스트와 추이 진입점.
///
/// 모의고사는 **항상 9등급제**다. 내신 등급제 설정을 참조하지 않는다.
struct MockExamListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \MockExamSession.examDate, order: .reverse)
    private var sessions: [MockExamSession]

    @State private var isAddingSession = false

    var body: some View {
        Group {
            if sessions.isEmpty {
                EmptyStateView(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "첫 모의고사 회차를 추가해 보세요",
                    message: "회차별 성적을 기록하면 추이를 볼 수 있습니다.",
                    actionTitle: "회차 추가",
                    action: { isAddingSession = true }
                )
            } else {
                List {
                    Section {
                        NavigationLink {
                            MockExamTrendView()
                        } label: {
                            Label("회차별 추이 보기", systemImage: "chart.xyaxis.line")
                        }
                    }

                    Section("회차") {
                        ForEach(sessions) { session in
                            NavigationLink {
                                MockExamDetailView(session: session)
                            } label: {
                                SessionRow(session: session)
                            }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingSession = true
                } label: {
                    Label("회차 추가", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingSession) {
            MockExamSessionFormView()
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
    }
}

private struct SessionRow: View {
    let session: MockExamSession

    private var recordCount: Int { session.subjectRecords?.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.name)
                .font(.body)
            Text("\(session.examDate.formatted(.dateTime.year().month().day())) · 과목 \(recordCount)개")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
