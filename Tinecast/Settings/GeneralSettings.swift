import SwiftUI
import TinecastKit

struct GeneralSettings: View {
    private static let reopenTimeouts: [(title: String, seconds: TimeInterval)] = [
        ("Immediately", 0), ("After 30 seconds", 30), ("After 90 seconds", 90), ("After 5 minutes", 300), ("Never", .infinity),
    ]

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Hotkey") {
                    ShortcutRecorder(combination: $model.config.hotkey)
                }
                Toggle("Open at login", isOn: $model.config.launchAtLogin)
                Toggle(isOn: $model.config.compact) {
                    Text("Compact mode")
                    Text("Shows only the search field until you start typing.")
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
                    Text("Clear search")
                    Text("When the panel reopens after this long, it starts with an empty search.")
                }
            }

            Section("File Search") {
                LabeledContent("Search in") {
                    PathList(title: "Folders to search", noun: "Folder", paths: $model.config.fileSearch.folders)
                }
                LabeledContent("Exclude") {
                    PathList(title: "Excluded folders", noun: "Exclusion", paths: $model.config.fileSearch.exclusions)
                }
            }

            Section("History") {
                TextField(text: historyIgnore, prompt: Text("Regular expression")) {
                    Text("Don't remember")
                    Text("Searches that fully match this aren't saved to history or ranking.")
                }
                .font(.body.monospaced())
                if let problem = model.config.historyIgnoreProblem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                LabeledContent {
                    Button("Open settings.json", action: model.openFile)
                } label: {
                    Text("Settings file")
                    Text("Edit every setting as JSON in your default text editor.")
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
