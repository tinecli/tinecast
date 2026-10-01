import SwiftUI
import TinecastKit

struct CommandsSettings: View {
    @Bindable var model: SettingsModel
    @State private var selection: String?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selection) {
                    ForEach(model.config.commands) { command in
                        Label {
                            Text(command.name.isEmpty ? "Untitled" : command.name)
                                .foregroundStyle(command.problem == nil ? .primary : .secondary)
                        } icon: {
                            Image(systemName: command.symbol)
                        }
                        .lineLimit(1)
                        .tag(command.id)
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: false))
                .accessibilityLabel("Commands")
                ListControls(addLabel: "Add Command", removeLabel: "Remove Command", add: add, remove: selection.map { id in { remove(id) } })
            }
            .frame(width: 200)
            .padding([.leading, .vertical], 20)
            if let selection, model.config.commands.contains(where: { $0.id == selection }) {
                CommandForm(model: model, command: binding(for: selection))
                    .id(selection)
            } else {
                ContentUnavailableView("No Command Selected", systemImage: "terminal", description: Text("Add a command with +, then run it from the search field by name or alias."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func add() {
        let command = Command(name: "", command: "")
        model.config.commands.append(command)
        selection = command.id
    }

    private func remove(_ id: String) {
        model.config.commands.removeAll { $0.id == id }
        model.config.setAlias("", for: "command:\(id)")
        model.config.setHidden(false, for: "command:\(id)")
        selection = nil
    }

    private func binding(for id: String) -> Binding<Command> {
        Binding(
            get: { model.config.commands.first { $0.id == id } ?? Command(id: id, name: "", command: "") },
            set: { command in
                guard let index = model.config.commands.firstIndex(where: { $0.id == id }) else { return }
                model.config.commands[index] = command
            }
        )
    }
}

private struct CommandForm: View {
    @Bindable var model: SettingsModel
    @Binding var command: Command

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $command.name, prompt: Text("Required"))
                if let problem = command.nameProblem {
                    problemLabel(problem)
                }
                LabeledContent("Icon") {
                    SymbolButton(symbol: $command.symbol)
                }
                AliasField(model: model, itemID: "command:\(command.id)", label: "Alias")
            }
            Section("Command") {
                TextEditor(text: $command.command)
                    .font(.body.monospaced())
                    .frame(minHeight: 64)
                    .accessibilityLabel("Command")
                executableStatus
                Toggle(isOn: $command.useShell) {
                    Text("Run in login shell")
                    Text("Loads your shell profile so aliases and PATH from it work. Slower.")
                }
                Toggle("Ask before running", isOn: $command.confirm)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var executableStatus: some View {
        if let problem = command.commandProblem {
            problemLabel(problem)
        } else if !command.useShell {
            switch Result(catching: { () throws(InvocationError) in try command.invocation() }) {
            case .success(let invocation):
                Text("Runs \(invocation.executable)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            case .failure(let error):
                problemLabel(error.errorDescription ?? "")
            }
        }
    }

    private func problemLabel(_ problem: String) -> some View {
        Label(problem, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
    }
}
