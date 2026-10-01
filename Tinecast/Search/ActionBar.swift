import SwiftUI
import TinecastKit

struct ActionBar: View {
    static let controlHeight: CGFloat = 28
    static let edgeInset = LauncherView.cornerRadius - controlHeight / 2
    static let height = controlHeight + 2 * edgeInset

    let item: Item?
    let run: (Item) -> Void
    let reveal: (Item) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let fill = (colorScheme == .dark ? Color.white : .black).opacity(contrast == .increased ? 0.22 : 0.11)
        HStack {
            Spacer()
            if let item {
                HStack(spacing: 14) {
                    Button { run(item) } label: {
                        ShortcutLabel(title: openTitle(for: item), shortcut: "↵")
                    }
                    if case .open = item.action {
                        Button { reveal(item) } label: {
                            ShortcutLabel(title: "Show in Finder", shortcut: "⌘↵")
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: Self.controlHeight)
                .background(fill, in: .capsule)
            }
        }
        .frame(height: Self.controlHeight)
        .padding(Self.edgeInset)
    }

    private func openTitle(for item: Item) -> String {
        switch item.action {
        case .open(let url):
            url.pathExtension == "app" ? "Open Application" : "Open"
        case .copy:
            "Copy Answer"
        case .run, .system:
            "Run"
        }
    }
}

private struct ShortcutLabel: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Text(shortcut)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}
