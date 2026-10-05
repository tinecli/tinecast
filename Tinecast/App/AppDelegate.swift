import AppKit
import ServiceManagement
import TinecastKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    #if DEBUG
    private static let folder = SettingsSnapshot.requested == nil && PanelSnapshot.requested == nil
        ? URL.applicationSupportDirectory.appending(path: "dev.gustaf.tinecast", directoryHint: .isDirectory)
        : URL.temporaryDirectory.appending(path: "tinecast-snapshot", directoryHint: .isDirectory)
    #else
    private static let folder = URL.applicationSupportDirectory.appending(path: "dev.gustaf.tinecast", directoryHint: .isDirectory)
    #endif
    private static let settingsURL = folder.appending(path: "settings.json")
    private static let lifecycleLog = LogFile(url: folder.appending(path: "lifecycle.log"))
    private var terminationSignal: (any DispatchSourceSignal)?

    let settings: SettingsModel
    let updater = AppUpdater()
    private let panel: PanelController
    private var appsProvider: AppsProvider?
    private var hotKey: HotKey?
    private var hotKeyCombination: KeyCombination?
    private var configWatcher: ConfigWatcher?
    private var config: Config?

    override init() {
        let settings = SettingsModel(url: Self.settingsURL)
        self.settings = settings
        panel = PanelController(folder: Self.folder, settings: settings)
        super.init()
        settings.clearHistory = { [panel] in panel.clearHistory() }
        settings.resetRanking = { [panel] in panel.resetRanking() }
        settings.showPanel = { [panel] in panel.toggle() }
        #if DEBUG
        if let config = SettingsSnapshot.requested?.config { settings.adopt(config) }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        let senderPID = NSAppleEventManager.shared().currentAppleEvent?.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value
        Self.recordLifecycle(senderPID.map { "terminating, quit requested by pid \($0)" } ?? "terminating")
        updater.installOnQuit()
    }

    private static func recordLifecycle(_ event: String) {
        lifecycleLog.append("\(Date.now.ISO8601Format()) pid \(ProcessInfo.processInfo.processIdentifier) \(event)\n")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("tinecast waits for its hotkey")
        Self.recordLifecycle("launched")
        MainThreadWatchdog.shared?.start()
        signal(SIGTERM, SIG_IGN)
        terminationSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        terminationSignal?.setEventHandler {
            Self.recordLifecycle("received SIGTERM")
            exit(0)
        }
        terminationSignal?.resume()
        appsProvider = AppsProvider { [panel, settings] apps in
            panel.model.apps = apps
            settings.apps = apps
        }
        #if DEBUG
        if let snapshot = SettingsSnapshot.requested {
            Task { await snapshot.capture() }
            return
        }
        if let snapshot = PanelSnapshot.requested {
            Task { [panel] in await snapshot.capture(panel) }
            return
        }
        #endif
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        configWatcher = ConfigWatcher(
            url: Self.settingsURL,
            onReload: { [weak self] config in self?.apply(config) },
            onInvalid: { [settings] problem in
                settings.reject(problem)
                presentAlert("settings.json has a problem", "\(problem)\n\ntinecast keeps its current settings until the file is fixed.")
            }
        )
        if config == nil { register(Config().hotkey) }
        updater.start()
    }

    private func apply(_ new: Config) {
        let old = config
        config = new
        panel.model.config = new
        settings.adopt(new)
        register(new.hotkey)
        if new.launchAtLogin != old?.launchAtLogin { setLaunchAtLogin(new.launchAtLogin) }
    }

    private func register(_ combination: KeyCombination) {
        let isNewCombination = combination != hotKeyCombination
        guard isNewCombination || hotKey == nil else { return }
        hotKeyCombination = combination
        hotKey = nil
        hotKey = HotKey(keyCode: combination.keyCode, modifiers: combination.carbonModifiers) { [panel] in panel.toggle() }
        settings.isHotkeyRegistered = hotKey != nil
        guard hotKey == nil, isNewCombination else { return }
        presentAlert(
            "\(combination.displayName) is already in use",
            "tinecast opens with \(combination.displayName), but another app or a system shortcut already uses it. Free it in System Settings > Keyboard > Keyboard Shortcuts (Spotlight and Input Sources use Command-Space and Control-Space), or choose another hotkey in tinecast Settings."
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
