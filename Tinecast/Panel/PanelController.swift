import AppKit
import QuartzCore
import SwiftUI
import TinecastKit

final class PanelController: NSObject, NSWindowDelegate, NSMenuDelegate {
    let model: LauncherModel
    private let settings: SettingsModel
    private let panel = LauncherPanel()
    private let moreMenu = NSMenu()
    private let actionsAnchor = NSView()
    private let ratesProvider: RatesProvider
    private let systemActions = SystemActionRunner()
    private let historyFile: JSONFile<History>
    private let frecencyFile: JSONFile<Frecency>
    private var previousApp: NSRunningApplication?
    private var openSettingsWindow: OpenWindowAction?

    init(folder: URL, settings: SettingsModel) {
        historyFile = JSONFile(url: folder.appending(path: "history.json"))
        frecencyFile = JSONFile(url: folder.appending(path: "ranking.json"))
        let model = LauncherModel()
        self.model = model
        self.settings = settings
        ratesProvider = RatesProvider(file: JSONFile(url: folder.appending(path: "rates.json"))) { rates in
            model.exchangeRates = rates
            settings.exchangeRates = rates
        }
        super.init()
        model.refreshRates = { [weak ratesProvider] in ratesProvider?.refreshIfStale() }
        settings.refreshRates = { [weak ratesProvider] in await ratesProvider?.refreshNow() ?? false }
        ratesProvider.refreshIfStale()
        model.history = historyFile.load() ?? History()
        model.frecency = frecencyFile.load() ?? Frecency()

        let hostingView = NSHostingView(rootView: LauncherView(
            model: model,
            run: { [weak self] item in self?.run(item) },
            reveal: { [weak self] item in self?.reveal(item) },
            cancel: { [weak self] in self?.close() },
            showMoreMenu: { [weak self] anchor in self?.showMoreMenu(above: anchor) },
            actionsAnchor: actionsAnchor,
            showActions: { [weak self] in self?.showActionMenu() },
            registerOpenSettings: { [weak self] action in self?.openSettingsWindow = action }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.setContentSize(LauncherView.windowSize)
        panel.delegate = self
        panel.handleKeyEquivalent = { [weak self] event in self?.handleKeyEquivalent(event) ?? false }
        moreMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        moreMenu.addItem(.separator())
        moreMenu.addItem(withTitle: "Quit tinecast", action: #selector(NSApplication.terminate), keyEquivalent: "q").target = NSApp
    }

    func toggle() {
        if model.isPresented {
            close()
        } else {
            show()
        }
    }

    func clearHistory() {
        model.history = History()
        historyFile.save(model.history)
    }

    func resetRanking() {
        model.frecency = Frecency()
        frecencyFile.save(model.frecency)
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }

    private func show() {
        let mouse = NSEvent.mouseLocation
        guard let visible = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main)?.visibleFrame else { return }

        previousApp = NSWorkspace.shared.frontmostApplication
        panel.setFrameTopLeftPoint(NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.maxY - visible.height / 5 + LauncherView.margin))
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        withAnimation(.launcher) { model.present() }
        // A non-activating panel can lose the first key request while another app activates.
        DispatchQueue.main.async { [panel] in
            guard panel.isVisible, !panel.isKeyWindow else { return }
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func close() {
        dismiss()
        previousApp?.activate()
    }

    private func showMoreMenu(above anchor: NSView) {
        moreMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height + moreMenu.size.height), in: anchor)
    }

    private func showActionMenu() {
        guard let item = model.selectedItem, actionsAnchor.window != nil else { return }
        let menu = actionMenu(for: item)
        menu.popUp(positioning: nil, at: NSPoint(x: actionsAnchor.bounds.width - menu.size.width, y: actionsAnchor.bounds.height + menu.size.height), in: actionsAnchor)
    }

    private func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers.contains(.command) else { return false }
        if modifiers == .command, event.charactersIgnoringModifiers == "k" {
            showActionMenu()
            return true
        }
        if moreMenu.performKeyEquivalent(with: event) { return true }
        guard let item = model.selectedItem else { return false }
        return actionMenu(for: item).performKeyEquivalent(with: event)
    }

    private func actionMenu(for item: Item) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let groups = ItemAction.groups(for: item) { url in
            NSWorkspace.shared.runningApplications.contains { $0.bundleURL?.standardizedFileURL.path == url.standardizedFileURL.path }
        }
        for (index, group) in groups.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for action in group {
                let (title, key, modifiers): (String, String, NSEvent.ModifierFlags) = switch action {
                case .open: ("Open", "\r", [])
                case .run: ("Run", "\r", [])
                case .copyAnswer: ("Copy Answer", "\r", [])
                case .copyDecimal: ("Copy Decimal", "", [])
                case .copyExpression: ("Copy Expression", "", [])
                case .showInFinder: ("Show in Finder", "\r", .command)
                case .openWith: ("Open With", "", [])
                case .copyPath: ("Copy Path", "C", .command)
                case .quitApp: ("Quit \(item.title)", "", [])
                case .moveToTrash: ("Move to Trash", "", [])
                case .editInSettings: ("Edit in Settings…", "", [])
                case .setAlias: ("Set Alias…", "", [])
                case .hideFromSearch: ("Hide from Search", "", [])
                }
                let menuItem = menu.addItem(withTitle: title, action: #selector(performMenuAction), keyEquivalent: key)
                menuItem.keyEquivalentModifierMask = modifiers
                menuItem.target = self
                menuItem.representedObject = action
                guard action == .openWith else { continue }
                menuItem.action = nil
                menuItem.submenu = NSMenu()
                menuItem.submenu?.delegate = self
            }
        }
        return menu
    }

    @objc private func performMenuAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? ItemAction, let item = model.selectedItem else { return }
        switch action {
        case .open, .run, .copyAnswer:
            run(item)
        case .copyDecimal:
            guard case .copy(_, let decimal?) = item.action else { return }
            run(Item(id: item.id, title: item.title, icon: item.icon, action: .copy(decimal)))
        case .copyExpression:
            run(Item(id: item.id, title: item.title, icon: item.icon, action: .copy(item.subtitle ?? "")))
        case .showInFinder:
            reveal(item)
        case .openWith:
            break
        case .copyPath:
            guard case .open(let url) = item.action else { return }
            run(Item(id: item.id, title: item.title, icon: item.icon, action: .copy(url.path(percentEncoded: false))))
        case .quitApp:
            guard case .open(let url) = item.action else { return }
            hide()
            NSWorkspace.shared.runningApplications.first { $0.bundleURL?.standardizedFileURL.path == url.standardizedFileURL.path }?.terminate()
        case .moveToTrash:
            guard case .open(let url) = item.action else { return }
            hide()
            guard presentAlert("Move “\(item.title)” to the Trash?", confirming: "Move to Trash") else { return }
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                presentAlert("“\(item.title)” couldn’t be moved to the Trash", error.localizedDescription)
            }
        case .editInSettings, .setAlias:
            let pane: Pane = switch item.action {
            case .run: .commands
            case .system: .systemActions
            case .open, .copy: .applications
            }
            settings.requestedReveal = SearchResult(pane: pane, title: item.title, icon: item.icon, anchor: item.id, filter: pane == .commands ? nil : "")
            openSettings()
        case .hideFromSearch:
            settings.setHidden(true, for: item.id)
            model.config.setHidden(true, for: item.id)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.items.isEmpty, case .open(let url) = model.selectedItem?.action else { return }
        let workspace = NSWorkspace.shared
        let defaultApplication = workspace.urlForApplication(toOpen: url)
        let others = workspace.urlsForApplications(toOpen: url)
            .filter { $0 != defaultApplication }
            .map { (url: $0, title: FileManager.default.displayName(atPath: $0.path(percentEncoded: false))) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let preferred = defaultApplication.map { [(url: $0, title: "\(FileManager.default.displayName(atPath: $0.path(percentEncoded: false))) (default)")] } ?? []
        for (index, application) in (preferred + others).enumerated() {
            if index == preferred.count, index > 0 { menu.addItem(.separator()) }
            let menuItem = menu.addItem(withTitle: application.title, action: #selector(openWithApplication), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = application.url
            menuItem.image = workspace.icon(forFile: application.url.path(percentEncoded: false))
            menuItem.image?.size = NSSize(width: 16, height: 16)
        }
    }

    func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent, target: AutoreleasingUnsafeMutablePointer<AnyObject?>, action: UnsafeMutablePointer<Selector?>) -> Bool {
        false
    }

    @objc private func openWithApplication(_ sender: NSMenuItem) {
        guard let application = sender.representedObject as? URL, let item = model.selectedItem, case .open(let url) = item.action else { return }
        perform(item) { NSWorkspace.shared.open([url], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration()) }
    }

    @objc private func openSettings() {
        hide()
        NSApp.activate()
        openSettingsWindow?(id: "settings")
    }

    private func run(_ item: Item) {
        perform(item) {
            switch item.action {
            case .open(let url):
                NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
            case .copy(let text, _):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                previousApp?.activate()
            case .run(let command):
                previousApp?.activate()
                guard !command.confirm || presentAlert("Run “\(command.name)”?", confirming: "Run") else { return }
                do {
                    let invocation = try command.invocation()
                    launchInBackground("“\(command.name)” failed", invocation.executable, invocation.arguments)
                } catch {
                    presentAlert("“\(command.name)” failed", error.localizedDescription)
                }
            case .system(let action):
                previousApp?.activate()
                systemActions.perform(action, frontmost: previousApp)
            }
        }
    }

    private func reveal(_ item: Item) {
        guard case .open(let url) = item.action else { return }
        perform(item) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    private func perform(_ item: Item, _ body: () -> Void) {
        hide()
        body()
        remember(item)
        MainThreadWatchdog.shared?.note("ran \(item.title), panel visible after hide: \(panel.isVisible)")
    }

    private func remember(_ item: Item) {
        let history = model.history
        let frecency = model.frecency
        model.record(item)
        if model.history != history { historyFile.save(model.history) }
        if model.frecency != frecency { frecencyFile.save(model.frecency) }
    }

    func hide() {
        panel.alphaValue = 0
        model.dismiss()
        CATransaction.flush()
        DispatchQueue.main.async { [panel] in
            panel.makeFirstResponder(nil)
            panel.orderOut(nil)
            panel.alphaValue = 1
            MainThreadWatchdog.shared?.note("deferred orderOut done")
        }
        MainThreadWatchdog.shared?.note("hide: invisible")
    }

    private func dismiss() {
        guard model.isPresented else { return }
        withAnimation(.launcher) {
            model.dismiss()
        } completion: { [weak self] in
            guard let self, !model.isPresented else { return }
            panel.orderOut(nil)
        }
    }
}
