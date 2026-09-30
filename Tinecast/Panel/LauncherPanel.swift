import AppKit

final class LauncherPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        alphaValue = 0
    }

    override var canBecomeKey: Bool { true }
}
