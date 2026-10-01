import SwiftUI

struct AliasField: View {
    @Bindable var model: SettingsModel
    let itemID: String
    let label: String
    @State private var draft = ""

    var body: some View {
        TextField(label, text: $draft, prompt: Text("Add Alias"))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(width: 110)
            .overlay(alignment: .trailing) {
                if !draft.isEmpty {
                    Button("Clear Alias", systemImage: "xmark.circle.fill") { draft = "" }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("Clear Alias")
                        .padding(.trailing, 4)
                }
            }
            .onChange(of: model.config.aliases[itemID], initial: true) { _, saved in
                guard draft.trimmingCharacters(in: .whitespacesAndNewlines) != (saved ?? "") else { return }
                draft = saved ?? ""
            }
            .onChange(of: draft) {
                guard draft.trimmingCharacters(in: .whitespacesAndNewlines) != (model.config.aliases[itemID] ?? "") else { return }
                model.config.setAlias(draft, for: itemID)
            }
    }
}
