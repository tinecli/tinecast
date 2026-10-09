import SwiftUI
import TineCastKit

struct CommandEditor: View {
    let isNew: Bool
    let save: (Command, String) -> Void
    @State private var draft: Command
    @State private var alias: String
    @Environment(\.dismiss) private var dismiss

    init(command: Command, alias: String, isNew: Bool, save: @escaping (Command, String) -> Void) {
        self.isNew = isNew
        self.save = save
        _draft = State(initialValue: command)
        _alias = State(initialValue: alias)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isNew ? "Add Command" : "Edit Command")
                .font(.headline)
                .padding(.top, 20)
            Form {
                Section {
                    HStack(spacing: 12) {
                        Text("Name")
                        TextField("Name", text: $draft.name, prompt: Text("Required"))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                            .labelsHidden()
                        SymbolButton(symbol: $draft.symbol)
                    }
                }
                Section {
                    TextEditor(text: $draft.command)
                        .font(.body.monospaced())
                        .frame(height: 64)
                        .accessibilityLabel("Command")
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
                    TextField("Alias", text: $alias, prompt: Text("None"))
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
                Button("Save", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.problem != nil)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460, height: 500)
        .onKeyPress(.return, phases: .down) { press in
            guard press.modifiers.contains(.command), draft.problem == nil else { return .ignored }
            commit()
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

    private func commit() {
        save(draft, alias)
        dismiss()
    }
}
