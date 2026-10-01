import SwiftUI

struct GeneralPane: View {
    private static let clearSearchDelays: [(title: String, seconds: TimeInterval)] = [
        ("Immediately", 0), ("30 Seconds", 30), ("90 Seconds", 90), ("5 Minutes", 300), ("Never", .infinity),
    ]

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            PaneHeader(pane: .general)
            Section("Global Shortcut") {
                LabeledContent("Open tinecast") {
                    ShortcutRecorder(combination: $model.config.hotkey)
                }
                if !model.isHotkeyRegistered {
                    Text("\(model.config.hotkey.displayName) is used by another app or a system shortcut. Choose another.")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            Section("General") {
                Toggle("Open at Login", isOn: $model.config.launchAtLogin)
                Picker("Clear Search After", selection: $model.config.reopenTimeout) {
                    ForEach(Self.clearSearchDelays, id: \.seconds) { option in
                        Text(option.title).tag(option.seconds)
                    }
                    if !Self.clearSearchDelays.contains(where: { $0.seconds == model.config.reopenTimeout }) {
                        Text(Duration.seconds(model.config.reopenTimeout).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
                            .tag(model.config.reopenTimeout)
                    }
                }
                Toggle(isOn: $model.config.compact) {
                    Text("Compact Bar")
                    Text("A slim search bar that expands as you type.")
                }
            }
            Section("Advanced") {
                LabeledContent("settings.json") {
                    Button("Open", action: model.openFile)
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }
}
