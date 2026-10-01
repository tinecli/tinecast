import SwiftUI
import TinecastKit

struct CommandsSettings: View {
    let model: SettingsModel
    @State private var selection: String?
    @State private var editing: Command?

    var body: some View {
        content
            .sheet(item: $editing) { command in
                CommandEditor(model: model, command: command)
            }
    }

    @ViewBuilder private var content: some View {
        if model.config.commands.isEmpty {
            ContentUnavailableView {
                Label("No Commands", systemImage: "terminal")
            } description: {
                Text("Run shell commands from the search field by name or alias.")
            } actions: {
                Button("Add Command…", action: add)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selection) {
                    ForEach(model.config.commands) { command in
                        CommandRow(command: command, alias: model.config.aliases["command:\(command.id)"]) {
                            editing = command
                        }
                        .tag(command.id)
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: false))
                .accessibilityLabel("Commands")
                .contextMenu(forSelectionType: String.self) { ids in
                    if let id = ids.first {
                        Button("Edit…") { edit(id) }
                        Button("Delete", role: .destructive) { ids.forEach(remove) }
                    }
                } primaryAction: { ids in
                    guard let id = ids.first else { return }
                    edit(id)
                }
                ListControls(addLabel: "Add Command…", removeLabel: "Remove Command", add: add, remove: selection.map { id in { remove(id) } })
            }
            .padding(20)
        }
    }

    private func add() {
        editing = Command(name: "", command: "")
    }

    private func edit(_ id: String) {
        editing = model.config.commands.first { $0.id == id }
    }

    private func remove(_ id: String) {
        model.config.commands.removeAll { $0.id == id }
        model.config.setAlias("", for: "command:\(id)")
        model.config.setHidden(false, for: "command:\(id)")
        if selection == id { selection = nil }
    }
}

private struct CommandRow: View {
    let command: Command
    let alias: String?
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Tile(symbol: command.symbol, color: .indigo, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                Text(command.command)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            if let alias {
                Text(alias)
                    .font(.caption)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: .capsule)
                    .accessibilityLabel("Alias \(alias)")
            }
            Button(action: edit) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .help("Edit Command")
            .accessibilityLabel("Edit \(command.name)")
        }
        .padding(.vertical, 4)
    }
}

private struct CommandEditor: View {
    let model: SettingsModel
    @State private var draft: Command
    @State private var alias: String
    @Environment(\.dismiss) private var dismiss

    init(model: SettingsModel, command: Command) {
        self.model = model
        _draft = State(initialValue: command)
        _alias = State(initialValue: model.config.aliases["command:\(command.id)"] ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $draft.name, prompt: Text("Required"))
                }
                Section("Command") {
                    TextEditor(text: $draft.command)
                        .font(.body.monospaced())
                        .frame(minHeight: 64)
                        .accessibilityLabel("Command")
                    if let status {
                        if status.isProblem {
                            Label(status.text, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.red)
                        } else {
                            Text(status.text)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                Section {
                    LabeledContent("Icon") {
                        SymbolButton(symbol: $draft.symbol)
                    }
                    TextField("Alias", text: $alias, prompt: Text("None"))
                    Toggle("Ask Before Running", isOn: $draft.confirm)
                    Toggle("Run in Login Shell", isOn: $draft.useShell)
                } footer: {
                    Text("A login shell loads your profile, so its aliases and PATH work.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.problem != nil)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460, height: 500)
    }

    private var status: (text: String, isProblem: Bool)? {
        guard !draft.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if let problem = draft.commandProblem { return (problem, true) }
        guard !draft.useShell else { return nil }
        do {
            return ("Runs \(try draft.invocation().executable)", false)
        } catch {
            return (error.errorDescription ?? "", true)
        }
    }

    private func save() {
        if let index = model.config.commands.firstIndex(where: { $0.id == draft.id }) {
            model.config.commands[index] = draft
        } else {
            model.config.commands.append(draft)
        }
        model.config.setAlias(alias, for: "command:\(draft.id)")
        dismiss()
    }
}
