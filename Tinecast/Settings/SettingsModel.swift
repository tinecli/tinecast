import AppKit
import Observation
import TinecastKit
import UniformTypeIdentifiers

@Observable
final class SettingsModel {
    private static let saveDelay = Duration.milliseconds(250)

    let url: URL
    var config = Config() {
        didSet {
            if config.commands != oldValue.commands { commandItems = config.commands.map(\.item) }
            scheduleSave()
        }
    }
    private(set) var fileProblem: String?
    private(set) var applications: [Item] = []
    private(set) var commandItems: [Item] = []
    var exchangeRates: ExchangeRates?
    var isHotkeyRegistered = true
    var requestedPane: Pane?
    var requestedReveal: SearchResult?
    @ObservationIgnored var apps = AppCatalog() {
        didSet { applications = apps.alphabetical }
    }
    @ObservationIgnored var refreshRates: () async -> Bool = { false }
    @ObservationIgnored var repairAppIndex: () async throws -> Int = { 0 }
    @ObservationIgnored var clearHistory: () -> Void = {}
    @ObservationIgnored var resetRanking: () -> Void = {}
    @ObservationIgnored var showPanel: () -> Void = {}
    @ObservationIgnored private var saved: Config?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    init(url: URL) {
        self.url = url
    }

    func setAlias(_ alias: String?, for itemID: String) {
        var updated = config
        updated.setAlias(alias ?? "", for: itemID)
        guard updated != config else { return }
        config = updated
    }

    func setHidden(_ hidden: Bool, for itemID: String) {
        guard config.hiddenItems.contains(itemID) != hidden else { return }
        config.setHidden(hidden, for: itemID)
    }

    func saveCommand(_ command: Command) {
        guard let index = config.commands.firstIndex(where: { $0.id == command.id }) else {
            config.commands.append(command)
            return
        }
        config.commands[index] = command
    }

    func duplicateCommand(_ command: Command) {
        let copy = Command(name: "\(command.name) Copy", command: command.command, symbol: command.symbol, confirm: command.confirm, useShell: command.useShell)
        let index = config.commands.firstIndex { $0.id == command.id }.map { $0 + 1 } ?? config.commands.endIndex
        config.commands.insert(copy, at: index)
    }

    func deleteCommand(_ command: Command) {
        var updated = config
        updated.commands.removeAll { $0.id == command.id }
        updated.setAlias("", for: command.item.id)
        updated.setHidden(false, for: command.item.id)
        config = updated
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
