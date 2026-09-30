import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = PanelController()
    private var appsProvider: AppsProvider?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appsProvider = AppsProvider { [panel] items in panel.model.items = items }
        hotKey = HotKey(keyCode: kVK_Space, modifiers: controlKey) { [panel] in panel.toggle() }
        guard hotKey == nil else { return }

        let alert = NSAlert()
        alert.messageText = "Control-Space is already in use"
        alert.informativeText = "tinecast opens with Control-Space, but another app or a system shortcut already uses it. Free it in System Settings > Keyboard > Keyboard Shortcuts (for example under Input Sources), then open tinecast again."
        NSApp.activate()
        alert.runModal()
    }
}
