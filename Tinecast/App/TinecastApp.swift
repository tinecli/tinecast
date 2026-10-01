import SwiftUI

@main
struct TinecastApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            SettingsView(model: appDelegate.settings)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 640)
    }
}
