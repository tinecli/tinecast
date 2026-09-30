import SwiftUI
import TinecastKit

struct ResultRow: View {
    static let iconSize: CGFloat = 28
    static let iconSpacing: CGFloat = 10
    static let horizontalPadding: CGFloat = 10

    let item: Item
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Self.iconSpacing) {
            icon
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
        }
        .padding(.horizontal, Self.horizontalPadding)
        .frame(maxHeight: .infinity)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? Color.accentColor : Color.clear, in: .rect(corners: .concentric(minimum: 16)))
        .contentShape(.rect)
    }

    @ViewBuilder private var icon: some View {
        switch item.icon {
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
                .resizable()
                .scaledToFit()
        case .symbol(let name):
            Image(systemName: name)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
