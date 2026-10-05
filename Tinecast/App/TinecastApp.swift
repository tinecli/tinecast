import SwiftUI

@main
struct TinecastApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("tinecast Settings", id: "settings") {
            SettingsView(model: appDelegate.settings)
                .environment(appDelegate.updater)
        }
        .windowToolbarStyle(.unified)
        .defaultLaunchBehavior(launchBehavior)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 640)
        Window("Welcome to tinecast", id: "welcome") {
            WelcomeView(model: appDelegate.settings)
        }
        .defaultLaunchBehavior(WelcomeView.launchBehavior)
        .restorationBehavior(.disabled)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private var launchBehavior: SceneLaunchBehavior {
        #if DEBUG
        if SettingsSnapshot.requested?.windowID == "settings" { return .presented }
        #endif
        return .suppressed
    }
}
