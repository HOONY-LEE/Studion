import SwiftUI

/// 오답노트 카드 한 장.
struct WrongAnswerCard: View {
    let text: String
    let causeTag: WrongAnswerCauseTag
    let englishSubcategory: EnglishSubcategory?
    let isDue: Bool
    let imageData: Data?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.subheadline)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    tagChip(causeTag.displayName)
                    if let englishSubcategory {
                        tagChip(englishSubcategory.displayName)
                    }
                    if isDue {
                        tagChip(String(localized: "복습할 차례"), emphasized: true)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func tagChip(_ title: String, emphasized: Bool = false) -> some View {
        Text(title)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                emphasized ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12),
                in: Capsule()
            )
            .foregroundStyle(emphasized ? Color.accentColor : .secondary)
    }

    private var accessibilityText: String {
        var parts = [text, causeTag.displayName]
        if let englishSubcategory { parts.append(englishSubcategory.displayName) }
        if isDue { parts.append(String(localized: "복습할 차례")) }
        return parts.joined(separator: ", ")
    }
}
