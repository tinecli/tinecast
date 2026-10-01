import SwiftUI
import TinecastKit

struct CommandsSettings: View {
    let model: SettingsModel
    @State private var editing: Command?
    @State private var deleting: Command?

    var body: some View {
        Form {
            Section {
                if model.config.commands.isEmpty {
                    Text("No commands yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.config.commands) { command in
                    CommandRow(
                        command: command,
                        alias: model.config.aliases["command:\(command.id)"],
                        edit: { editing = command },
                        duplicate: { duplicate(command) },
                        delete: { deleting = command }
                    )
                }
            } footer: {
                HStack {
                    Spacer()
                    Button("Add Command…") { editing = Command(name: "", command: "") }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { command in
            CommandEditor(model: model, command: command)
        }
        .alert(
            "Delete “\(deleting?.name ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            presenting: deleting
        ) { command in
            Button("Delete", role: .destructive) { remove(command.id) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func duplicate(_ command: Command) {
        let copy = Command(name: "\(command.name) Copy", command: command.command, symbol: command.symbol, confirm: command.confirm, useShell: command.useShell)
        let index = model.config.commands.firstIndex { $0.id == command.id }.map { $0 + 1 } ?? model.config.commands.endIndex
        model.config.commands.insert(copy, at: index)
    }

    private func remove(_ id: String) {
        model.config.commands.removeAll { $0.id == id }
        model.config.setAlias("", for: "command:\(id)")
        model.config.setHidden(false, for: "command:\(id)")
    }
}

private struct CommandRow: View {
    let command: Command
    let alias: String?
    let edit: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: command.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
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

private struct CommandEditor: View {
    let model: SettingsModel
    private let isNew: Bool
    @State private var draft: Command
    @State private var alias: String
    @Environment(\.dismiss) private var dismiss

    init(model: SettingsModel, command: Command) {
        self.model = model
        isNew = !model.config.commands.contains { $0.id == command.id }
        _draft = State(initialValue: command)
        _alias = State(initialValue: model.config.aliases["command:\(command.id)"] ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isNew ? "Add Command" : "Edit Command")
                .font(.headline)
                .padding(.top, 20)
            Form {
                Section {
                    LabeledContent("Name") {
                        HStack(spacing: 8) {
                            TextField("Name", text: $draft.name, prompt: Text("Required"))
                                .labelsHidden()
                            SymbolButton(symbol: $draft.symbol)
                        }
                    }
                    TextField("Alias", text: $alias, prompt: Text("None"))
                }
                Section {
                    TextField("Command", text: $draft.command, prompt: Text("Required"), axis: .vertical)
                        .labelsHidden()
                        .font(.body.monospaced())
                        .lineLimit(1...4)
                } header: {
                    Text("Command")
                } footer: {
                    if let status {
                        if status.isProblem {
                            Label(status.text, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        } else {
                            Text(status.text)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                Section {
                    Toggle("Ask Before Running", isOn: $draft.confirm)
                    Toggle(isOn: $draft.useShell) {
                        Text("Run in Login Shell")
                        Text("Loads your profile, so its aliases and PATH work.")
                    }
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
        .frame(width: 460, height: 440)
        .onKeyPress(.return, phases: .down) { press in
            guard press.modifiers.contains(.command), draft.problem == nil else { return .ignored }
            save()
            return .handled
        }
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
