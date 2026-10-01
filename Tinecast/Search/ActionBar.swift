import SwiftUI
import TinecastKit

struct ActionBar: View {
    private static let controlHeight: CGFloat = 28
    private static let edgeInset: CGFloat = 8
    static let height = controlHeight + 2 * edgeInset

    let item: Item?
    let material: Config.Material
    let run: (Item) -> Void
    let reveal: (Item) -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        GlassEffectContainer {
            HStack {
                Menu {
                    Button("Settings…", action: openSettings)
                        .keyboardShortcut(",")
                    Divider()
                    Button("Quit tinecast", action: quit)
                        .keyboardShortcut("q")
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .menuIndicator(.hidden)
                .foregroundStyle(.secondary)
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .contentShape(.circle)
                .modifier(Surface(material: material, shape: .circle))
                .glassEffectTransition(.materialize)
                .accessibilityLabel("More")
                Spacer()
                if let item {
                    HStack(spacing: 14) {
                        Button { run(item) } label: {
                            ShortcutLabel(title: openTitle(for: item), glyphs: ["↵"])
                        }
                        Button { reveal(item) } label: {
                            ShortcutLabel(title: "Show in Finder", glyphs: ["⌘", "↵"])
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: Self.controlHeight)
                    .modifier(Surface(material: material, shape: .capsule))
                    .glassEffectTransition(.materialize)
                }
            }
            .font(.callout)
            .padding(Self.edgeInset)
        }
    }

    private func openTitle(for item: Item) -> String {
        switch item.action {
        case .open(let url):
            url.pathExtension == "app" ? "Open Application" : "Open"
        }
    }
}

private struct ShortcutLabel: View {
    let title: String
    let glyphs: [String]

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .padding(.trailing, 3)
            ForEach(glyphs, id: \.self) { glyph in
                Text(glyph)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, minHeight: 18)
                    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary) }
                    .accessibilityHidden(true)
            }
        }
    }
}
