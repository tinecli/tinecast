import SwiftUI

struct HistoryPane: View {
    @Bindable var model: SettingsModel
    @State private var isConfirmingClear = false
    @State private var isConfirmingReset = false

    var body: some View {
        Form {
            Section {
                PaneHeader(pane: .history)
            }
            Section {
                LabeledContent {
                    TextField(SettingRow.historyIgnore.label, text: historyIgnore, prompt: Text("Regular Expression"))
                        .labelsHidden()
                        .font(.body.monospaced())
                } label: {
                    Text(SettingRow.historyIgnore.label)
                    Text("Matching searches aren’t saved or learned from.")
                }
                .modifier(SearchAnchor(id: SettingRow.historyIgnore.rawValue))
                if let problem = model.config.historyIgnoreProblem {
                    Text(problem)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            Section {
                LabeledContent(SettingRow.searchHistory.label) {
                    Button("Clear Search History…") { isConfirmingClear = true }
                }
                .modifier(SearchAnchor(id: SettingRow.searchHistory.rawValue))
                LabeledContent {
                    Button("Reset Suggestions…") { isConfirmingReset = true }
                } label: {
                    Text(SettingRow.suggestions.label)
                    Text("Recent items and the ranking learned from what you open.")
                }
                .modifier(SearchAnchor(id: SettingRow.suggestions.rawValue))
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
