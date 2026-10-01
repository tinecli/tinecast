import SwiftUI
import TinecastKit

struct GeneralSettings: View {
    private static let reopenTimeouts: [(title: String, seconds: TimeInterval)] = [
        ("Immediately", 0), ("30 Seconds", 30), ("90 Seconds", 90), ("5 Minutes", 300), ("Never", .infinity),
    ]

    @Bindable var model: SettingsModel
    @State private var isRefreshingRates = false
    @State private var ratesRefreshFailed = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Hotkey") {
                    ShortcutRecorder(combination: $model.config.hotkey)
                }
                if !model.isHotkeyRegistered {
                    Label("\(model.config.hotkey.glyphs) is already used by another app or a system shortcut.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Toggle("Open at Login", isOn: $model.config.launchAtLogin)
                Toggle(isOn: $model.config.compact) {
                    Text("Compact Bar")
                    Text("Shows only the search field until you type.")
                }
                Picker("Clear Search After", selection: $model.config.reopenTimeout) {
                    ForEach(Self.reopenTimeouts, id: \.seconds) { option in
                        Text(option.title).tag(option.seconds)
                    }
                    if !Self.reopenTimeouts.contains(where: { $0.seconds == model.config.reopenTimeout }) {
                        Text(Duration.seconds(model.config.reopenTimeout).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
                            .tag(model.config.reopenTimeout)
                    }
                }
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
                    TextField("Ignore Searches Matching", text: historyIgnore, prompt: Text("Regular Expression"))
                        .labelsHidden()
                        .font(.body.monospaced())
                } label: {
                    Text("Ignore Searches Matching")
                    Text("Matching searches aren't saved to history.")
                }
                if let problem = model.config.historyIgnoreProblem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                LabeledContent("Exchange Rates") {
                    HStack(spacing: 8) {
                        if isRefreshingRates {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Refreshing")
                        }
                        Text(ratesStatus)
                            .foregroundStyle(.secondary)
                        Button("Refresh", action: refreshRates)
                            .disabled(isRefreshingRates)
                    }
                    .lineLimit(1)
                    .fixedSize()
                }
            } footer: {
                HStack {
                    Spacer()
                    Button("Open settings.json", action: model.openFile)
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

    private var ratesStatus: String {
        if ratesRefreshFailed { return "Couldn't Refresh" }
        guard let rates = model.exchangeRates else { return "Not Downloaded" }
        return (try? Date.ISO8601FormatStyle().year().month().day().parse(rates.date))?.formatted(date: .abbreviated, time: .omitted) ?? rates.date
    }

    private func refreshRates() {
        isRefreshingRates = true
        Task {
            ratesRefreshFailed = !(await model.refreshRates())
            isRefreshingRates = false
        }
    }
}
