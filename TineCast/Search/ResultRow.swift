import SwiftUI
import TineCastKit

struct ResultRow: View {
    static let iconSize: CGFloat = 28
    static let iconSpacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 10

    let item: Item
    let alias: String?
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
                HStack(spacing: 6) {
                    Text(item.title)
                        .lineLimit(1)
                    if let alias {
                        Text(alias)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background((colorScheme == .dark ? Color.white : .black).opacity(0.08), in: .rect(cornerRadius: 5, style: .continuous))
                            .accessibilityLabel("Alias \(alias)")
                    }
                }
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
