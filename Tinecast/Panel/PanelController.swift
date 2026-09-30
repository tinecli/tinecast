import AppKit
import SwiftUI
import TinecastKit

final class PanelController: NSObject, NSWindowDelegate {
    let model = LauncherModel()
    private let panel = LauncherPanel()
    private var previousApp: NSRunningApplication?

    override init() {
        super.init()
        let hostingView = NSHostingView(rootView: LauncherView(
            model: model,
            run: { [weak self] item in self?.run(item) },
            cancel: { [weak self] in self?.close() },
            resize: { [weak self] size in self?.resize(to: size) }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.delegate = self
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
        model.isPresented = true
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

    private func run(_ item: Item) {
        dismiss()
        switch item.action {
        case .open(let url):
            NSWorkspace.shared.open(url)
        }
    }

    private func dismiss() {
        guard model.isPresented else { return }
        model.isPresented = false
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
        model.query = ""
    }

    private func resize(to size: CGSize) {
        let frame = panel.frame
        panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height), display: true)
        panel.invalidateShadow()
    }
}
