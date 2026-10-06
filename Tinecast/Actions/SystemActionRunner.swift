import AppKit
import Carbon.HIToolbox
import IOKit.hidsystem
import TinecastKit

final class SystemActionRunner {
    private static let finderBundleID = "com.apple.finder"
    private static let accessibilitySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    private var hasPromptedForAccessibility = false

    func perform(_ action: SystemAction, frontmost: NSRunningApplication?) {
        let failed = "\(action.item.title) didn't work"
        switch action {
        case .lockScreen:
            guard isAccessibilityTrusted() else { return }
            for keyDown in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_Q), keyDown: keyDown)
                event?.flags = [.maskControl, .maskCommand]
                event?.post(tap: .cghidEventTap)
            }
        case .sleep:
            launchInBackground(failed, "/usr/bin/pmset", ["sleepnow"])
        case .sleepDisplays:
            launchInBackground(failed, "/usr/bin/pmset", ["displaysleepnow"])
        case .restart:
            guard presentAlert("Are you sure you want to restart your computer now?", confirming: "Restart") else { return }
            launchInBackground(failed, "/usr/bin/osascript", ["-e", #"tell application "System Events" to restart"#])
        case .shutDown:
            guard presentAlert("Are you sure you want to shut down your computer now?", confirming: "Shut Down") else { return }
            launchInBackground(failed, "/usr/bin/osascript", ["-e", #"tell application "System Events" to shut down"#])
        case .logOut:
            guard presentAlert("Are you sure you want to quit all apps and log out now?", confirming: "Log Out") else { return }
            launchInBackground(failed, "/usr/bin/osascript", ["-e", #"tell application "System Events" to log out"#])
        case .startScreenSaver:
            NSWorkspace.shared.openApplication(at: URL(filePath: "/System/Library/CoreServices/ScreenSaverEngine.app"), configuration: NSWorkspace.OpenConfiguration())
        case .playPause:
            postMediaKey(NX_KEYTYPE_PLAY)
        case .nextTrack:
            postMediaKey(NX_KEYTYPE_NEXT)
        case .previousTrack:
            postMediaKey(NX_KEYTYPE_PREVIOUS)
        case .volumeUp:
            guard !changeOutputVolume(by: 1) else { return }
            presentAlert(failed, "The current sound output device doesn't support volume control.")
        case .volumeDown:
            guard !changeOutputVolume(by: -1) else { return }
            presentAlert(failed, "The current sound output device doesn't support volume control.")
        case .toggleMute:
            guard !toggleOutputMute() else { return }
            presentAlert(failed, "The current sound output device can't be muted.")
        case .showDesktop:
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = ["1"]
            NSWorkspace.shared.openApplication(at: URL(filePath: "/System/Applications/Mission Control.app"), configuration: configuration)
        case .toggleDarkMode:
            launchInBackground(failed, "/usr/bin/osascript", ["-e", #"tell application "System Events" to tell appearance preferences to set dark mode to not dark mode"#])
        case .openTrash:
            guard let trash = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return }
            NSWorkspace.shared.open(trash)
        case .emptyTrash:
            guard presentAlert("Are you sure you want to permanently erase the items in the Trash?", "You can't undo this action.", confirming: "Empty Trash") else { return }
            launchInBackground(failed, "/usr/bin/osascript", ["-e", #"tell application "Finder" to empty trash"#])
        case .ejectAllDisks:
            launchInBackground(failed, "/usr/bin/osascript", ["-e", #"tell application "Finder" to eject (every disk whose ejectable is true)"#])
        case .hideOtherApps:
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0 != frontmost }
                .forEach { $0.hide() }
        case .showAllApps:
            NSWorkspace.shared.runningApplications.forEach { $0.unhide() }
        case .quitAllApps:
            guard presentAlert("Are you sure you want to quit all apps?", "Apps with unsaved changes may ask you to save them first.", confirming: "Quit All Apps") else { return }
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0 != .current && $0.bundleIdentifier != Self.finderBundleID }
                .forEach { $0.terminate() }
        }
    }

    private func isAccessibilityTrusted() -> Bool {
        let prompts = !hasPromptedForAccessibility
        hasPromptedForAccessibility = true
        guard !AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompts] as CFDictionary) else { return true }
        guard !prompts else { return false }
        let opensSettings = presentAlert(
            "Tinecast needs Accessibility access",
            "Lock Screen and the media actions work by sending keystrokes, which macOS only allows for apps turned on in System Settings > Privacy & Security > Accessibility.",
            confirming: "Open System Settings"
        )
        if opensSettings { NSWorkspace.shared.open(Self.accessibilitySettings) }
        return false
    }

    private func postMediaKey(_ key: Int32) {
        guard isAccessibilityTrusted() else { return }
        for (flags, state) in [(0xa00, 0xa), (0xb00, 0xb)] {
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: Int(key) << 16 | state << 8,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
