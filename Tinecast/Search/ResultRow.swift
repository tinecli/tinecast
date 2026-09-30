import SwiftUI
import TinecastKit

struct ResultRow: View {
    let item: Item
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(.quaternary.opacity(isSelected ? 1 : 0), in: .rect(cornerRadius: 8))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var icon: Image {
        switch item.icon {
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
        case .symbol(let name):
            Image(systemName: name)
        }
    }
}
