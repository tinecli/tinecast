import SwiftUI

enum Pane: String {
    case general, permissions, applications, commands, systemActions, files, calculator, history

    static let sidebarGroups: [(header: String?, panes: [Pane])] = [
        (nil, [.general, .permissions]),
        ("Search", [.applications, .commands, .systemActions, .files]),
        ("Tools", [.calculator, .history]),
    ]

    var title: String { details.title }
    var symbol: String { details.symbol }
    var color: Color { details.color }
    var summary: String { details.summary }

    func matches(_ query: String) -> Bool {
        query.isEmpty || ([details.title] + details.keywords).contains { $0.localizedStandardContains(query) }
    }

    private var details: (title: String, symbol: String, color: Color, summary: String, keywords: [String]) {
        switch self {
        case .general: (
            "General", "gearshape.fill", .gray,
            "Choose how Tinecast opens and behaves.",
            []
        )
        case .permissions: (
            "Permissions", "hand.raised.fill", .blue,
            "Allow access for actions that control your Mac.",
            ["Privacy", "Automation"]
        )
        case .applications: (
            "Applications", "square.grid.2x2.fill", .blue,
            "Give apps an alias or hide them from search.",
            ["Apps", "Alias", "Hide"]
        )
        case .commands: (
            "Commands", "terminal.fill", Color(white: 0.2),
            "Run your own commands from Tinecast.",
            ["Shell", "Script", "Terminal", "Alias"]
        )
        case .systemActions: (
            "System Actions", "bolt.fill", .orange,
            "Actions that control your Mac.",
            ["Power", "Media", "Alias", "Hide"]
        )
        case .files: (
            "Files", "folder.fill", .blue,
            "Choose where file search looks.",
            ["File Search", "Folders"]
        )
        case .calculator: (
            "Calculator", "plus.forwardslash.minus", Color(white: 0.4),
            "Unit conversion, precision and exchange rates.",
            ["Exchange Rates", "Currency"]
        )
        case .history: (
            "History", "clock.arrow.circlepath", .purple,
            "Control what Tinecast remembers.",
            ["Privacy"]
        )
        }
    }
}

struct PaneHistory {
    private var visited: [Pane]
    private var position = 0

    init(start: Pane = .general) {
        visited = [start]
    }

    var current: Pane { visited[position] }
    var canGoBack: Bool { position > 0 }
    var canGoForward: Bool { position < visited.count - 1 }

    mutating func visit(_ pane: Pane) {
        guard pane != current else { return }
        visited = Array(visited[...position]) + [pane]
        position += 1
    }

    mutating func goBack() {
        position = max(position - 1, 0)
    }

    mutating func goForward() {
        position = min(position + 1, visited.count - 1)
    }
}

struct PaneTile: View {
    let symbol: String
    let color: Color
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size / 4, style: .continuous)
            .fill(color.gradient)
            .overlay {
                RoundedRectangle(cornerRadius: size / 4, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            }
            .overlay {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.regular)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
                    .frame(width: size * 0.6, height: size * 0.6)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

extension PaneTile {
    init(pane: Pane, size: CGFloat) {
        self.init(symbol: pane.symbol, color: pane.color, size: size)
    }
}

struct PaneHeader: View {
    let pane: Pane

    var body: some View {
        HStack(spacing: 8) {
            PaneTile(pane: pane, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(pane.title)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                Text(pane.summary)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
