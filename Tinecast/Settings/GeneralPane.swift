import SwiftUI

struct GeneralPane: View {
    private static let clearSearchDelays: [(title: String, seconds: TimeInterval)] = [
        ("Immediately", 0), ("30 Seconds", 30), ("90 Seconds", 90), ("5 Minutes", 300), ("Never", .infinity),
    ]

    @Bindable var model: SettingsModel
    @Environment(AppUpdater.self) private var updater

    var body: some View {
        Form {
            Section {
                PaneHeader(pane: .general)
            }
            Section("Global Shortcut") {
                LabeledContent(SettingRow.hotkey.label) {
                    ShortcutRecorder(combination: $model.config.hotkey)
                }
                .modifier(SearchAnchor(id: SettingRow.hotkey.rawValue))
                if !model.isHotkeyRegistered {
                    Text("\(model.config.hotkey.displayName) is used by another app or a system shortcut. Choose another.")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            Section("General") {
                Toggle(SettingRow.openAtLogin.label, isOn: $model.config.launchAtLogin)
                    .modifier(SearchAnchor(id: SettingRow.openAtLogin.rawValue))
                Picker(SettingRow.clearSearchAfter.label, selection: $model.config.reopenTimeout) {
                    ForEach(Self.clearSearchDelays, id: \.seconds) { option in
                        Text(option.title).tag(option.seconds)
                    }
                    if !Self.clearSearchDelays.contains(where: { $0.seconds == model.config.reopenTimeout }) {
                        Text(Duration.seconds(model.config.reopenTimeout).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
                            .tag(model.config.reopenTimeout)
                    }
                }
                .modifier(SearchAnchor(id: SettingRow.clearSearchAfter.rawValue))
                Toggle(isOn: $model.config.compact) {
                    Text(SettingRow.compactBar.label)
                    Text("A slim search bar that expands as you type.")
                }
                .modifier(SearchAnchor(id: SettingRow.compactBar.rawValue))
            }
            Section("Updates") {
                LabeledContent(SettingRow.version.label, value: AppUpdater.currentVersion)
                    .modifier(SearchAnchor(id: SettingRow.version.rawValue))
                HStack(spacing: 8) {
                    updateStatus
                    Spacer()
                    if updater.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(updater.status == .checking ? "Checking" : "Downloading")
                    }
                    if updater.staged != nil {
                        Button("Install and Relaunch", action: updater.installAndRelaunch)
                    } else {
                        Button(SettingRow.checkForUpdates.label) { updater.check(.manual) }
                            .disabled(updater.isBusy)
                    }
                }
                .modifier(SearchAnchor(id: SettingRow.checkForUpdates.rawValue))
            }
            Section("Advanced") {
                LabeledContent(SettingRow.settingsFile.label) {
                    Button("Open", action: model.openFile)
                }
                .modifier(SearchAnchor(id: SettingRow.settingsFile.rawValue))
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }

    @ViewBuilder private var updateStatus: some View {
        switch updater.status {
        case .idle: EmptyView()
        case .checking: Text("Checking for updates…").font(.callout).foregroundStyle(.secondary)
        case .downloading: Text("Downloading the update…").font(.callout).foregroundStyle(.secondary)
        case .upToDate(let version): Text("tinecast \(version) is the latest version.").font(.callout).foregroundStyle(.secondary)
        case .ready(let version): Text("tinecast \(version) is ready to install.").font(.callout)
        case .blocked(let message): Text(message).font(.callout).foregroundStyle(.orange)
        case .failed(let message): Text(message).font(.callout).foregroundStyle(.red)
        }
    }
}
