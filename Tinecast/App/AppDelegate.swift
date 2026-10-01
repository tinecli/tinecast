import AppKit
import ServiceManagement
import TinecastKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let folder = URL.applicationSupportDirectory.appending(path: "dev.gustaf.tinecast", directoryHint: .isDirectory)
    private static let settingsURL = folder.appending(path: "settings.json")

    private let panel = PanelController(folder: AppDelegate.folder, settingsURL: AppDelegate.settingsURL)
    private var appsProvider: AppsProvider?
    private var hotKey: HotKey?
    private var hotKeyCombination: KeyCombination?
    private var configWatcher: ConfigWatcher?
    private var config: Config?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        appsProvider = AppsProvider { [panel] apps in panel.model.apps = apps }
        configWatcher = ConfigWatcher(
            url: Self.settingsURL,
            onReload: { [weak self] config in self?.apply(config) },
            onInvalid: { problem in
                presentAlert("settings.json has a problem", "\(problem)\n\ntinecast keeps its current settings until the file is fixed.")
            }
        )
        if config == nil { register(Config().hotkey) }
    }

    private func apply(_ new: Config) {
        let old = config
        config = new
        panel.model.config = new
        register(new.hotkey)
        if new.launchAtLogin != old?.launchAtLogin { setLaunchAtLogin(new.launchAtLogin) }
    }

    private func register(_ combination: KeyCombination) {
        let isNewCombination = combination != hotKeyCombination
        guard isNewCombination || hotKey == nil else { return }
        hotKeyCombination = combination
        hotKey = nil
        hotKey = HotKey(keyCode: combination.keyCode, modifiers: combination.carbonModifiers) { [panel] in panel.toggle() }
        guard hotKey == nil, isNewCombination else { return }
        presentAlert(
            "\(combination.displayName) is already in use",
            "tinecast opens with \(combination.displayName), but another app or a system shortcut already uses it. Free it in System Settings > Keyboard > Keyboard Shortcuts (Spotlight and Input Sources use Command-Space and Control-Space), or choose another hotkey in settings.json."
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        let isRegistered = service.status == .enabled || service.status == .requiresApproval
        guard enabled != isRegistered else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            presentAlert("Launch at login couldn't be changed", error.localizedDescription)
        }
    }
}
