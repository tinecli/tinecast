import SwiftUI
import TinecastKit

struct CommandRow: View {
    let command: Command
    let alias: String?
    let edit: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

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
            Button("Edit \(command.name)", systemImage: "info.circle", action: edit)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .imageScale(.large)
                .help("Edit")
        }
        .contentShape(.rect)
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
