import SwiftUI
import TinecastKit

struct ActionBar: View {
    static let controlHeight: CGFloat = 28
    static let edgeInset = LauncherView.cornerRadius - controlHeight / 2
    static let height = controlHeight + 2 * edgeInset

    let item: Item?
    let run: (Item) -> Void
    let reveal: (Item) -> Void
    let showMoreMenu: (NSView) -> Void
    let actionsAnchor: NSView
    let showActions: () -> Void

    @State private var moreMenuAnchor = NSView()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let fill = (colorScheme == .dark ? Color.white : .black).opacity(contrast == .increased ? 0.22 : 0.11)
        HStack {
            Button { showMoreMenu(moreMenuAnchor) } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .focusable(false)
            .background(MenuAnchor(view: moreMenuAnchor))
            .accessibilityLabel("More")
            Spacer()
            if let item {
                HStack(spacing: 14) {
                    Button { run(item) } label: {
                        ShortcutLabel(title: openTitle(for: item), shortcut: "↵")
                    }
                    if item.kind == "File" {
                        Button { reveal(item) } label: {
                            ShortcutLabel(title: "Show in Finder", shortcut: "⌘↵")
                        }
                    }
                    Button(action: showActions) {
                        ShortcutLabel(title: "Actions", shortcut: "⌘K")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: Self.controlHeight)
                .background(fill, in: .capsule)
                .background(MenuAnchor(view: actionsAnchor))
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

private struct MenuAnchor: NSViewRepresentable {
    let view: NSView

    func makeNSView(context: Context) -> NSView { view }

    func updateNSView(_ nsView: NSView, context: Context) {}
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
