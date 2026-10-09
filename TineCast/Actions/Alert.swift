import AppKit

@discardableResult
func presentAlert(_ message: String, _ information: String = "", confirming button: String? = nil) -> Bool {
    let previousApp = NSWorkspace.shared.frontmostApplication
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = information
    if let button {
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancel")
    }
    NSApp.activate()
    let response = alert.runModal()
    previousApp?.activate()
    return response == .alertFirstButtonReturn
}
