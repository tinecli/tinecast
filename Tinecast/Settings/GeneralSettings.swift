import SwiftUI
import TinecastKit

struct GeneralSettings: View {
    private static let reopenTimeouts: [(title: String, seconds: TimeInterval)] = [
        ("Immediately", 0), ("After 30 Seconds", 30), ("After 90 Seconds", 90), ("After 5 Minutes", 300), ("Never", .infinity),
    ]

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    ShortcutRecorder(combination: $model.config.hotkey)
                } label: {
                    Label { Text("Hotkey") } icon: { Tile(symbol: "keyboard", color: .gray) }
                }
                Toggle(isOn: $model.config.launchAtLogin) {
                    Label { Text("Open at Login") } icon: { Tile(symbol: "power", color: .green) }
                }
                Toggle(isOn: $model.config.compact) {
                    Label { Text("Compact Mode") } icon: { Tile(symbol: "rectangle.compress.vertical", color: .blue) }
                }
                Picker(selection: $model.config.reopenTimeout) {
                    ForEach(Self.reopenTimeouts, id: \.seconds) { option in
                        Text(option.title).tag(option.seconds)
                    }
                    if !Self.reopenTimeouts.contains(where: { $0.seconds == model.config.reopenTimeout }) {
                        Text("After \(Duration.seconds(model.config.reopenTimeout).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))")
                            .tag(model.config.reopenTimeout)
                    }
                } label: {
                    Label { Text("Clear Search") } icon: { Tile(symbol: "clock.arrow.circlepath", color: .orange) }
                }
            } footer: {
                Text("Compact Mode shows only the search field until you start typing.")
                    .foregroundStyle(.secondary)
            }

            Section("File Search") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Folders")
                    FolderList(title: "Folders", paths: $model.config.fileSearch.folders)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Excluded Folders")
                    FolderList(title: "Excluded Folders", paths: $model.config.fileSearch.exclusions)
                }
            }

            Section {
                LabeledContent {
                    TextField("Ignore Searches", text: historyIgnore, prompt: Text("Regular Expression"))
                        .labelsHidden()
                        .font(.body.monospaced())
                } label: {
                    Label { Text("Ignore Searches") } icon: { Tile(symbol: "clock.badge.xmark", color: .purple) }
                }
                if let problem = model.config.historyIgnoreProblem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            } header: {
                Text("History")
            } footer: {
                Text("Searches that fully match this aren't saved to history or ranking.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    Button("Open", action: model.openFile)
                } label: {
                    Label { Text("settings.json") } icon: { Tile(symbol: "curlybraces", color: .gray) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var historyIgnore: Binding<String> {
        Binding(
            get: { model.config.historyIgnore ?? "" },
            set: { model.config.historyIgnore = $0.isEmpty ? nil : $0 }
        )
    }
}
