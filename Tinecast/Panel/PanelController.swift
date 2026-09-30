import AppKit
import SwiftUI
import TinecastKit

final class PanelController: NSObject, NSWindowDelegate {
    let model = LauncherModel()
    private let panel = LauncherPanel()
    private let historyURL: URL
    private let frecencyURL: URL
    private let settingsURL: URL
    private var previousApp: NSRunningApplication?

    init(folder: URL, settingsURL: URL) {
        historyURL = folder.appending(path: "history.json")
        frecencyURL = folder.appending(path: "ranking.json")
        self.settingsURL = settingsURL
        super.init()
        model.history = (try? JSONDecoder().decode(History.self, from: Data(contentsOf: historyURL))) ?? History()
        model.frecency = (try? JSONDecoder().decode(Frecency.self, from: Data(contentsOf: frecencyURL))) ?? Frecency()

        let hostingView = NSHostingView(rootView: LauncherView(
            model: model,
            run: { [weak self] item in self?.run(item) },
            cancel: { [weak self] in self?.close() },
            openSettings: { [weak self] in self?.openSettings() },
            quit: { NSApp.terminate(nil) },
            resize: { [weak self] size in self?.resize(to: size) }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
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
        panel.setFrameTopLeftPoint(NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.maxY - visible.height / 5))
        model.present()
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
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
        remember(item)
        dismiss()
        switch item.action {
        case .open(let url):
            NSWorkspace.shared.open(url)
        }
    }

    private func revealSelection() {
        guard let item = model.selectedItem else { return }
        remember(item)
        dismiss()
        switch item.action {
        case .open(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func remember(_ item: Item) {
        let history = model.history
        model.record(item)
        if model.history != history {
            try? JSONEncoder().encode(model.history).write(to: historyURL, options: .atomic)
        }
        try? JSONEncoder().encode(model.frecency).write(to: frecencyURL, options: .atomic)
    }

    private func dismiss() {
        guard model.isPresented else { return }
        model.dismiss()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.finishDismiss() }
        }
    }

    private func finishDismiss() {
        guard !model.isPresented else { return }
        panel.orderOut(nil)
    }

    private func resize(to size: CGSize) {
        let frame = panel.frame
        panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height), display: true)
        panel.invalidateShadow()
    }
}
