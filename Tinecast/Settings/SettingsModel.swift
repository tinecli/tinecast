import AppKit
import Observation
import TinecastKit
import UniformTypeIdentifiers

@Observable
final class SettingsModel {
    private static let saveDelay = Duration.milliseconds(250)

    let url: URL
    var config = Config() {
        didSet { scheduleSave() }
    }
    private(set) var fileProblem: String?
    var apps = AppCatalog()
    var exchangeRates: ExchangeRates?
    var isHotkeyRegistered = true
    @ObservationIgnored var refreshRates: () async -> Bool = { false }
    @ObservationIgnored private var saved: Config?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    init(url: URL) {
        self.url = url
    }

    var items: [Item] {
        apps.alphabetical + config.commands.map(\.item) + SystemAction.allCases.map(\.item)
    }

    func adopt(_ loaded: Config) {
        fileProblem = nil
        guard loaded != saved else {
            scheduleSave()
            return
        }
        saved = loaded
        pendingSave?.cancel()
        config = loaded
    }

    func reject(_ problem: String) {
        pendingSave?.cancel()
        fileProblem = problem
    }

    func openFile() {
        let workspace = NSWorkspace.shared
        guard let editor = workspace.urlForApplication(toOpen: .plainText) ?? workspace.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else {
            workspace.open(url)
            return
        }
        workspace.open([url], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            guard (try? await Task.sleep(for: Self.saveDelay)) != nil else { return }
            self?.save()
        }
    }

    private func save() {
        guard fileProblem == nil, let saved else { return }
        let valid = config.keepingValidValues(from: saved)
        guard valid != saved else { return }
        do {
            try valid.json().write(to: url, options: .atomic)
            self.saved = valid
        } catch {
            presentAlert("Settings couldn't be saved", error.localizedDescription)
        }
    }
}
