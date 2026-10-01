import AppKit
import SwiftUI
import TinecastKit

final class PanelController: NSObject, NSWindowDelegate {
    let model: LauncherModel
    private let panel = LauncherPanel()
    private let ratesProvider: RatesProvider
    private let systemActions = SystemActionRunner()
    private let historyFile: JSONFile<History>
    private let frecencyFile: JSONFile<Frecency>
    private var previousApp: NSRunningApplication?
    private var openSettingsWindow: OpenSettingsAction?

    init(folder: URL, settings: SettingsModel) {
        historyFile = JSONFile(url: folder.appending(path: "history.json"))
        frecencyFile = JSONFile(url: folder.appending(path: "ranking.json"))
        let model = LauncherModel()
        self.model = model
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
            openSettings: { [weak self] in self?.openSettings() },
            registerOpenSettings: { [weak self] action in self?.openSettingsWindow = action },
            quit: { NSApp.terminate(nil) }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.setContentSize(LauncherView.windowSize)
        panel.delegate = self
        panel.commandShortcuts = [
            ",": { [weak self] in self?.openSettings() },
            "q": { NSApp.terminate(nil) },
            "\r": { [weak self] in
                guard let self, let item = model.selectedItem else { return }
                reveal(item)
            },
        ]
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
        withAnimation(.launcher) { model.present() }
    }

    private func close() {
        dismiss()
        previousApp?.activate()
    }

    private func openSettings() {
        hide()
        NSApp.activate()
        openSettingsWindow?()
    }

    private func run(_ item: Item) {
        perform(item) {
            switch item.action {
            case .open(let url):
                NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
            case .copy(let text):
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
    }

    private func remember(_ item: Item) {
        let history = model.history
        let frecency = model.frecency
        model.record(item)
        if model.history != history { historyFile.save(model.history) }
        if model.frecency != frecency { frecencyFile.save(model.frecency) }
    }

    private func hide() {
        model.dismiss()
        panel.orderOut(nil)
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
