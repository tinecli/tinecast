import SwiftUI

struct HistoryPane: View {
    @Bindable var model: SettingsModel
    @State private var isConfirmingClear = false
    @State private var isConfirmingReset = false

    var body: some View {
        Form {
            PaneHeader(pane: .history)
            Section {
                LabeledContent {
                    TextField("Ignore Searches Matching", text: historyIgnore, prompt: Text("Regular Expression"))
                        .labelsHidden()
                        .font(.body.monospaced())
                } label: {
                    Text("Ignore Searches Matching")
                    Text("Matching searches aren’t saved or learned from.")
                }
                if let problem = model.config.historyIgnoreProblem {
                    Text(problem)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            Section {
                LabeledContent("Search History") {
                    Button("Clear Search History…") { isConfirmingClear = true }
                }
                LabeledContent {
                    Button("Reset Suggestions…") { isConfirmingReset = true }
                } label: {
                    Text("Suggestions")
                    Text("Recent items and the ranking learned from what you open.")
                }
            }
        }
        .formStyle(.grouped)
        .alert("Clear Search History?", isPresented: $isConfirmingClear) {
            Button("Clear", role: .destructive, action: model.clearHistory)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Searches you can recall with the arrow keys are removed. This can’t be undone.")
        }
        .alert("Reset Suggestions?", isPresented: $isConfirmingReset) {
            Button("Reset", role: .destructive, action: model.resetRanking)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("tinecast forgets which results you choose for each search. This can’t be undone.")
        }
    }

    private var historyIgnore: Binding<String> {
        Binding(
            get: { model.config.historyIgnore ?? "" },
            set: { model.config.historyIgnore = $0.isEmpty ? nil : $0 }
        )
    }
}
