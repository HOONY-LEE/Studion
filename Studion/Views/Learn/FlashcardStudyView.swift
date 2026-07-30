import SwiftUI

/// 플래시카드 한 장. 탭하면 뒤집힌다.
///
/// 다른 문제 유형과 달리 위아래로 늘어놓지 않고 **카드 한 장에 담는다** — 앞면에는 문제만,
/// 뒷면에는 답만 둔다. 답을 떠올린 뒤 뒤집어 확인하는 것이 플래시카드의 전부이므로,
/// 화면에 그 두 가지 말고 다른 것이 보이면 방해가 된다.
struct FlashcardStudyView: View {
    let question: Question
    /// 뒤집힌 적이 있는지. 답을 본 뒤에만 "알았음/몰랐음"을 물어야 한다.
    @Binding var hasRevealed: Bool

    @State private var progress: Double = 0

    private var isShowingBack: Bool { progress >= 0.5 }

    var body: some View {
        VStack(spacing: 14) {
            FlipCard(progress: progress) {
                face(
                    label: "문제",
                    icon: "questionmark.circle",
                    text: question.prompt,
                    detail: question.hint.isEmpty ? nil : question.hint,
                    detailIcon: "lightbulb",
                    image: question.questionImageData
                )
            } back: {
                face(
                    label: "정답",
                    icon: "checkmark.circle",
                    text: question.flashcardBack,
                    detail: question.explanation.isEmpty ? nil : question.explanation,
                    detailIcon: nil,
                    image: question.explanationImageData
                )
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .onTapGesture(perform: flip)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isShowingBack ? "정답 면" : "문제 면")
            .accessibilityHint("두 번 탭하면 뒤집힙니다")
            .accessibilityAddTraits(.isButton)

            Label(isShowingBack ? "탭하면 문제로 돌아가요" : "탭해서 답 확인",
                  systemImage: "hand.tap")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        // 문제가 바뀌면 항상 앞면부터 — 앞 문제의 답이 보인 채로 시작하면 안 된다.
        .onChange(of: question.persistentModelID) { _, _ in
            progress = 0
        }
    }

    private func flip() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            progress = isShowingBack ? 0 : 1
        }
        if !hasRevealed { hasRevealed = true }
    }

    /// 카드 한 면. 글자를 크게 두고 여백을 넉넉히 준다 — 한 장에 담긴 정보가 적을수록
    /// 플래시카드는 잘 읽힌다.
    private func face(
        label: LocalizedStringKey,
        icon: String,
        text: String,
        detail: String?,
        detailIcon: String?,
        image: Data?
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)

            // 내용이 길면 카드 안에서만 스크롤한다. 카드 자체가 늘어나면 뒤집을 때 크기가
            // 변해 어지럽다.
            //
            // 짧은 내용은 카드 **한가운데**에 놓는다 — 단어 하나가 위에 붙어 있고 아래가
            // 텅 비면 카드처럼 읽히지 않는다. 그래서 스크롤 내용의 최소 높이를 보이는
            // 영역만큼 주고 가운데 정렬한다.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 14) {
                        if let image, let uiImage = UIImage(data: image) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Text(verbatim: text)
                            .font(.title2.weight(.medium))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity)

                        if let detail {
                            HStack(alignment: .top, spacing: 6) {
                                if let detailIcon {
                                    Image(systemName: detailIcon)
                                        .font(.caption)
                                        .padding(.top, 2)
                                }
                                Text(verbatim: detail)
                                    .font(.callout)
                                    .multilineTextAlignment(detailIcon == nil ? .center : .leading)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}
