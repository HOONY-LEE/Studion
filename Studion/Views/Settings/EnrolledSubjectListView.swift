import SwiftUI
import SwiftData

/// 이름 변경 대상 과목.
private struct RenameTarget: Identifiable {
    /// 현재 과목명. 이 값이 곧 식별자다 (과목 마스터 테이블이 없으므로).
    let id: String
    let affectedCount: Int
}

/// 이수 과목 관리. 학기를 가로질러 같은 과목명을 한 번에 바꾼다.
///
/// 과목 동일성은 `docs/02-data-model.md`의 규칙(trim 후 완전 일치)을 따른다.
/// 이름을 바꾸면 같은 이름을 쓰던 기존 기록도 함께 갱신해야 추이가 두 갈래로 쪼개지지 않는다.
struct EnrolledSubjectListView: View {
    @Environment(\.modelContext) private var context

    @Query private var records: [SchoolSubjectRecord]

    @State private var renaming: RenameTarget?

    /// 과목명별로 묶는다.
    private var subjectNames: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: records) { $0.subjectName.trimmed }
            .filter { !$0.key.isEmpty }
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if subjectNames.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet",
                    title: "등록된 과목이 없어요",
                    message: "성적 탭에서 학기를 만들고 과목을 추가하면 여기에 표시됩니다."
                )
            } else {
                List {
                    Section {
                        ForEach(subjectNames, id: \.name) { item in
                            Button {
                                renaming = RenameTarget(id: item.name, affectedCount: item.count)
                            } label: {
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    Text("\(item.count)개 학기")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteSubjects)
                    } footer: {
                        Text("이름을 바꾸면 같은 이름을 쓰던 모든 학기의 기록이 함께 바뀝니다.")
                    }
                }
            }
        }
        .navigationTitle("이수 과목")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $renaming) { target in
            RenameSheet(target: target) { newName in
                rename(from: target.id, to: newName)
            }
        }
    }

    private func rename(from oldName: String, to newName: String) {
        let trimmed = newName.trimmed
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        for record in records where record.subjectName.trimmed == oldName {
            record.subjectName = trimmed
        }
    }

    private func deleteSubjects(at offsets: IndexSet) {
        for index in offsets {
            let name = subjectNames[index].name
            for record in records where record.subjectName.trimmed == name {
                context.delete(record)
            }
        }
    }
}

private struct RenameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let target: RenameTarget
    let onSave: (String) -> Void

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("과목명", text: $name)
                } footer: {
                    Text("\(target.affectedCount)개 학기의 기록이 함께 바뀝니다.")
                }
            }
            .navigationTitle("과목명 바꾸기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmed.isEmpty)
                }
            }
            .onAppear { name = target.id }
        }
    }
}
