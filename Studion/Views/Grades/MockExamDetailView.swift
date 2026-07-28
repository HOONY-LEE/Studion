import SwiftUI
import SwiftData

/// 회차 상세. 과목별 기록을 관리한다.
struct MockExamDetailView: View {
    @Environment(\.modelContext) private var context

    let session: MockExamSession

    @State private var isAddingSubject = false
    @State private var subjectToEdit: MockExamSubjectRecord?

    private var records: [MockExamSubjectRecord] {
        (session.subjectRecords ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: "기록된 과목이 없어요",
                    message: "이 회차에서 본 과목의 성적을 추가해 보세요.",
                    actionTitle: "과목 추가",
                    action: { isAddingSubject = true }
                )
            } else {
                List {
                    ForEach(records) { record in
                        Button {
                            subjectToEdit = record
                        } label: {
                            MockExamSubjectRow(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingSubject = true
                } label: {
                    Label("과목 추가", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingSubject) {
            MockExamSubjectFormView(session: session)
        }
        .sheet(item: $subjectToEdit) { record in
            MockExamSubjectFormView(session: session, editing: record)
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            context.delete(records[index])
        }
    }
}

private struct MockExamSubjectRow: View {
    let record: MockExamSubjectRecord

    /// 입력되지 않은 값은 표시하지 않는다. 0으로 대체하지 않는다.
    ///
    /// `Text`를 이어붙이는 방식을 쓴다 — 라벨 부분을 먼저 `String`으로 합쳐버리면
    /// (`parts.joined(separator:)`) 로컬라이징 조회가 깨진다.
    private var detailText: Text? {
        var parts: [Text] = []
        if let rawScore = record.rawScore {
            parts.append(Text("원점수 \(rawScore.formatted(.number.precision(.fractionLength(0...1))))"))
        }
        if let standardScore = record.standardScore {
            parts.append(Text("표준 \(standardScore.formatted(.number.precision(.fractionLength(0...1))))"))
        }
        if let percentile = record.percentile {
            parts.append(Text("백분위 \(percentile.formatted(.number.precision(.fractionLength(0...1))))"))
        }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + Text(verbatim: " · ") + $1 }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.subjectName)
                    .font(.body)
                if let detailText {
                    detailText
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            GradeBadge(content: record.grade.map { .grade($0) } ?? .none)
        }
        .contentShape(Rectangle())
    }
}
