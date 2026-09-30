import AppKit
import SwiftUI
import TinecastKit

final class PanelController: NSObject, NSWindowDelegate {
    let model = LauncherModel()
    private let panel = LauncherPanel()
    private let historyFile: JSONFile<History>
    private let frecencyFile: JSONFile<Frecency>
    private let settingsURL: URL
    private var previousApp: NSRunningApplication?

    init(folder: URL, settingsURL: URL) {
        historyFile = JSONFile(url: folder.appending(path: "history.json"))
        frecencyFile = JSONFile(url: folder.appending(path: "ranking.json"))
        self.settingsURL = settingsURL
        super.init()
        model.history = historyFile.load() ?? History()
        model.frecency = frecencyFile.load() ?? Frecency()

        let hostingView = NSHostingView(rootView: LauncherView(
            model: model,
            run: { [weak self] item in self?.run(item) },
            cancel: { [weak self] in self?.close() },
            openSettings: { [weak self] in self?.openSettings() },
            quit: { NSApp.terminate(nil) }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.setContentSize(LauncherView.windowSize)
        panel.delegate = self
        panel.commandShortcuts = [
            ",": { [weak self] in self?.openSettings() },
            "q": { NSApp.terminate(nil) },
            "\r": { [weak self] in self?.revealSelection() },
        ]
    }

    func toggle() {
        if model.isPresented {
            close()
        } else {
            show()
        }
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
        dismiss()
        NSWorkspace.shared.open(settingsURL)
    }

    private func run(_ item: Item) {
        perform(item) { action in
            switch action {
            case .open(let url):
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func revealSelection() {
        guard let item = model.selectedItem else { return }
        perform(item) { action in
            switch action {
            case .open(let url):
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private func perform(_ item: Item, _ body: (TinecastKit.Action) -> Void) {
        remember(item)
        dismiss()
        body(item.action)
    }

    private func remember(_ item: Item) {
        let history = model.history
        let frecency = model.frecency
        model.record(item)
        if model.history != history { historyFile.save(model.history) }
        if model.frecency != frecency { frecencyFile.save(model.frecency) }
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
