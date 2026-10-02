import SwiftUI

@main
struct TinecastApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("tinecast Settings", id: "settings") {
            SettingsView(model: appDelegate.settings)
        }
        .windowToolbarStyle(.unified)
        .defaultLaunchBehavior(launchBehavior)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 640)
    }

    private var launchBehavior: SceneLaunchBehavior {
        #if DEBUG
        if SettingsSnapshot.requested != nil { return .presented }
        #endif
        return .suppressed
    }
}
