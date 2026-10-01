import SwiftUI
import TinecastKit

struct CommandsSettings: View {
    let model: SettingsModel
    @State private var editing: EditRequest?
    @State private var deleting: Command?

    var body: some View {
        let commands = model.config.commands
        let aliases = model.config.aliases
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsCard {
                    PaneHeader(pane: .commands)
                }
                if commands.isEmpty {
                    ContentUnavailableView {
                        Label("No Commands", systemImage: Pane.commands.symbol)
                    } description: {
                        Text("Commands you add appear in tinecast’s search.")
                    } actions: {
                        Button("Add Command…", action: add)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    SettingsCard {
                        ForEach(commands) { command in
                            CommandRow(
                                command: command,
                                alias: aliases[command.item.id],
                                edit: { editing = EditRequest(command: command, isNew: false) },
                                duplicate: { model.duplicateCommand(command) },
                                delete: { deleting = command }
                            )
                        }
                    }
                    HStack {
                        Spacer()
                        Button("Add Command…", action: add)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editing) { request in
            CommandEditor(command: request.command, alias: aliases[request.command.item.id] ?? "", isNew: request.isNew, save: { model.saveCommand($0); model.setAlias($1, for: $0.item.id) })
        }
        .alert(
            "Delete “\(deleting?.name ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            presenting: deleting
        ) { command in
            Button("Delete", role: .destructive) { model.deleteCommand(command) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It’s removed from tinecast’s search. This can’t be undone.")
        }
    }

    private func add() {
        editing = EditRequest(command: Command(name: "", command: ""), isNew: true)
    }
}

private struct EditRequest: Identifiable {
    let command: Command
    let isNew: Bool

    var id: String { command.id }
}
