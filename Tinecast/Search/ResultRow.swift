import SwiftUI
import TinecastKit

struct ResultRow: View {
    static let iconSize: CGFloat = 28
    static let iconSpacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 10

    let item: Item
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: Self.iconSpacing) {
            ItemIcon(icon: item.icon)
                .font(.title2)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
            if let kind = item.kind {
                Text(kind)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .frame(maxHeight: .infinity)
        .background(
            (colorScheme == .dark ? Color.white : .black)
                .opacity(contrast == .increased ? 0.22 : 0.11)
                .opacity(isSelected ? 1 : 0),
            in: .rect(corners: .concentric(minimum: 16))
        )
        .contentShape(.rect)
    }
}
