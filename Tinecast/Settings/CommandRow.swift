import SwiftUI
import TinecastKit

struct CommandRow: View {
    let command: Command
    let alias: String?
    let edit: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            PaneTile(symbol: command.symbol, color: Pane.commands.color, size: 20)
                .symbolVariant(.fill)
            VStack(alignment: .leading, spacing: 1) {
                Text(command.name)
                Text(command.command)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
            }
            .lineLimit(1)
            Spacer(minLength: 12)
            if let alias {
                Text(alias)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: .capsule)
                    .accessibilityLabel("Alias \(alias)")
            }
            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .opacity(isHovering ? 1 : 0)
            .accessibilityLabel("Actions for \(command.name)")
        }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2, perform: edit)
        .contextMenu { actions }
        .accessibilityActions { actions }
    }

    @ViewBuilder private var actions: some View {
        Button("Edit…", action: edit)
        Button("Duplicate", action: duplicate)
        Divider()
        Button("Delete…", role: .destructive, action: delete)
    }
}
