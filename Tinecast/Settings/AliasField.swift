import SwiftUI

struct AliasField: View {
    @Bindable var model: SettingsModel
    let itemID: String
    let label: String
    @State private var draft = ""

    var body: some View {
        TextField(label, text: $draft, prompt: Text("None"))
            .onChange(of: model.config.aliases[itemID], initial: true) { _, saved in
                guard draft.trimmingCharacters(in: .whitespacesAndNewlines) != (saved ?? "") else { return }
                draft = saved ?? ""
            }
            .onChange(of: draft) {
                model.config.setAlias(draft, for: itemID)
            }
    }
}
