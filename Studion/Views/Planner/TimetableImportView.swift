import SwiftUI
import SwiftData
import PhotosUI

/// 시간표 사진으로 한 번에 채우기.
///
/// 수업을 한 칸씩 손으로 넣으면 35칸을 채워야 한다. 사진 한 장으로 끝나면 훨씬 낫다.
///
/// **읽은 결과를 바로 저장하지 않는다.** OCR도 격자 추정도 틀리므로, 읽어낸 수업을 목록으로
/// 보여주고 **하나씩 끄고 켜고 고칠 수 있게** 한 뒤에만 저장한다 — 앱이 시간표를 확정하지
/// 않는다(원칙). 잘못 들어간 수업을 나중에 찾아 지우는 것보다 저장 전에 거르는 편이 쉽다.
struct TimetableImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    @AppStorage(PreferenceKey.periodSchedule) private var scheduleJSON = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isRecognizing = false
    @State private var result: TimetableOCRParser.Result?
    /// 읽어낸 수업들. 사용자가 고칠 수 있어야 하므로 복사해 들고 있는다.
    @State private var draft: [DraftEntry] = []
    @State private var errorMessage: String?

    /// 이미 시간표에 있는 수업. 같은 과목이면 색을 그대로 물려주기 위해 본다.
    @Query private var existingEntries: [TimetableEntry]

    private var schedule: SchoolPeriodSchedule { SchoolPeriodSchedule(json: scheduleJSON) }

    /// 읽어낸 과목마다 색을 나눠준다 — 사진 한 장으로 넣어도 과목별로 색이 갈리게.
    /// 이미 있는 과목은 그 색을 그대로 쓴다 (→ `TimetableColorAssigner`).
    private var colorAssignments: [String: Int] {
        TimetableColorAssigner.assign(
            titles: draft.map(\.title),
            existing: TimetableColorAssigner.existingAssignments(
                from: existingEntries.map { ($0.title, $0.colorIndex) }
            )
        )
    }

    private var selectedCount: Int { draft.filter(\.isIncluded).count }

    var body: some View {
        NavigationStack {
            Group {
                if isRecognizing {
                    ProgressView("시간표를 읽는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if draft.isEmpty {
                    startState
                } else {
                    reviewList
                }
            }
            .navigationTitle("사진으로 시간표 넣기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                if !draft.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("\(selectedCount)개 추가") { save() }
                            .disabled(selectedCount == 0)
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await recognize(item) }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { data in
                    Task { await recognize(data) }
                }
                .ignoresSafeArea()
            }
        }
    }

    /// 사진첩과 카메라 두 갈래. 카메라가 없는 기기(시뮬레이터)에서는 사진첩만 보인다.
    @ViewBuilder
    private var sourceButtons: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            Label("사진첩에서 고르기", systemImage: "photo.on.rectangle")
        }

        if CameraPicker.isAvailable {
            Button {
                isShowingCamera = true
            } label: {
                Label("시간표 촬영하기", systemImage: "camera")
            }
        }
    }

    // MARK: - 시작 화면

    private var startState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "text.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(verbatim: "시간표를 찍거나 사진첩에서 고르세요")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(verbatim: "읽어낸 수업을 확인하고 고친 뒤에 저장합니다. 바로 들어가지 않아요.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                sourceButtons
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage {
                Text(verbatim: errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Text(verbatim: "요일과 교시가 함께 찍히도록 표 전체를 반듯하게 찍으면 잘 읽힙니다.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
    }

    // MARK: - 확인 목록

    private var reviewList: some View {
        List {
            Section {
                ForEach($draft) { $entry in
                    row(for: $entry)
                }
            } header: {
                Text("읽어낸 수업 \(draft.count)개")
            } footer: {
                Text("잘못 읽은 것은 끄거나 고치세요. 켜둔 것만 시간표에 들어갑니다.")
            }

            Section {
                sourceButtons
            } header: {
                Text("다시 읽기")
            }
        }
    }

    private func row(for entry: Binding<DraftEntry>) -> some View {
        HStack(spacing: 12) {
            Button {
                entry.wrappedValue.isIncluded.toggle()
            } label: {
                Image(systemName: entry.wrappedValue.isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(entry.wrappedValue.isIncluded ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // 저장하면 어떤 색이 될지 여기서 미리 보여준다.
            RoundedRectangle(cornerRadius: 3)
                .fill(TimetableColorPalette.color(at: color(for: entry.wrappedValue.title)))
                .frame(width: 5)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: "\(weekdayName(entry.wrappedValue.dayIndex)) \(entry.wrappedValue.periodNumber)교시")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 과목과 교실은 둘 다 고칠 수 있는 칸이라 그냥 두면 어느 쪽이 무엇인지
                // 구분되지 않는다. 앞에 무엇을 적는 칸인지 이름표를 붙여 갈라 놓는다.
                fieldRow(label: "과목", systemImage: "book", text: entry.title,
                         placeholder: "과목명", isPrimary: true)
                fieldRow(label: "교실", systemImage: "mappin.and.ellipse", text: entry.location,
                         placeholder: "없음", isPrimary: false)
            }
        }
        .opacity(entry.wrappedValue.isIncluded ? 1 : 0.45)
        .frame(minHeight: 76)
    }

    /// 이름표 + 입력칸 한 줄. 이름표 너비를 고정해 과목·교실 칸의 왼쪽 끝이 맞아떨어지게 한다.
    private func fieldRow(
        label: LocalizedStringKey,
        systemImage: String,
        text: Binding<String>,
        placeholder: LocalizedStringKey,
        isPrimary: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)

            TextField(placeholder, text: text)
                .font(isPrimary ? .body : .subheadline)
                .foregroundStyle(isPrimary ? .primary : .secondary)
                .accessibilityLabel(label)
        }
    }

    private func color(for title: String) -> Int {
        colorAssignments[TimetableColorAssigner.key(for: title)] ?? 0
    }

    // MARK: - 동작

    private func recognize(_ item: PhotosPickerItem) async {
        // 같은 사진을 다시 고를 수 있게 선택을 비워 둔다 — 값이 그대로면 `onChange`가
        // 울리지 않아 두 번째 선택이 먹히지 않는다.
        defer { photoItem = nil }

        guard let raw = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "사진을 열지 못했어요."
            return
        }
        await recognize(raw)
    }

    private func recognize(_ raw: Data) async {
        errorMessage = nil
        isRecognizing = true
        defer { isRecognizing = false }

        // 원본 그대로는 인식이 느리다. 오답노트와 같은 방식으로 줄여서 넘긴다.
        let data = ImageDownsampler.downsample(raw)

        do {
            let boxes = try await TimetableTextRecognizer.recognizeBoxes(in: data)
            let parsed = TimetableOCRParser.parse(boxes)
            result = parsed

            if parsed.failedToBuildGrid {
                // "실패"라고 하지 않는다 — 사진을 어떻게 다시 찍으면 되는지 알려준다.
                errorMessage = "요일과 교시를 찾지 못했어요. 표의 요일 줄과 교시 번호가 함께 나오도록 다시 찍어보세요."
                return
            }
            if parsed.cells.isEmpty {
                errorMessage = "표는 찾았는데 수업 이름을 읽지 못했어요. 더 가까이서 밝게 찍어보세요."
                return
            }

            draft = parsed.cells
                .filter { schedule.period(number: $0.periodNumber) != nil }
                .map(DraftEntry.init)

            if draft.isEmpty {
                errorMessage = "읽어낸 교시가 지금 표에 없어요. 교시 시각에서 보여줄 교시 수를 늘려보세요."
            }
        } catch {
            errorMessage = "사진에서 글자를 읽지 못했어요."
        }
    }

    private func save() {
        // 색은 저장 직전에 한 번만 계산한다 — 칸마다 다시 계산하면 같은 과목이 다른 색을 받는다.
        let colors = colorAssignments

        for entry in draft where entry.isIncluded {
            let title = entry.title.trimmed
            guard !title.isEmpty, let period = schedule.period(number: entry.periodNumber) else { continue }

            let new = TimetableEntry(
                dayOfWeek: PlannerDateHelper.calendarWeekday(forDisplayIndex: entry.dayIndex),
                startTime: time(atMinutes: period.startMinutes),
                endTime: time(atMinutes: period.endMinutes),
                title: title,
                location: entry.location.trimmed,
                type: .school,
                colorIndex: colors[TimetableColorAssigner.key(for: title)] ?? 0
            )
            context.insert(new)
        }
        dismiss()
    }

    private func time(atMinutes minutes: Int) -> Date {
        calendar.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? Date()
    }

    private func weekdayName(_ displayIndex: Int) -> String {
        let weekday = PlannerDateHelper.calendarWeekday(forDisplayIndex: displayIndex)
        return calendar.shortWeekdaySymbols[weekday - 1]
    }

    /// 확인 화면에서 고칠 수 있게 감싼 한 줄.
    struct DraftEntry: Identifiable {
        let id = UUID()
        let dayIndex: Int
        let periodNumber: Int
        var title: String
        var location: String
        var isIncluded = true

        init(_ cell: TimetableOCRParser.Cell) {
            dayIndex = cell.dayIndex
            periodNumber = cell.periodNumber
            title = cell.title
            location = cell.location
        }
    }
}
