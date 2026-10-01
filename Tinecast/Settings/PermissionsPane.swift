import ApplicationServices
import ServiceManagement
import SwiftUI

private let systemEventsID = "com.apple.systemevents"
private let finderID = "com.apple.finder"
private let accessibilitySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
private let automationSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!

private enum PermissionStatus {
    case allowed, notAllowed, notSetUp, on, off, needsApproval

    init(automation status: OSStatus) {
        if status == noErr {
            self = .allowed
        } else if status == OSStatus(errAEEventNotPermitted) {
            self = .notAllowed
        } else {
            self = .notSetUp
        }
    }

    init(loginItem status: SMAppService.Status) {
        if status == .enabled {
            self = .on
        } else if status == .requiresApproval {
            self = .needsApproval
        } else {
            self = .off
        }
    }

    var title: String {
        switch self {
        case .allowed: "Allowed"
        case .notAllowed: "Not Allowed"
        case .notSetUp: "Not Set Up"
        case .on: "On"
        case .off: "Off"
        case .needsApproval: "Needs Approval"
        }
    }
}

@concurrent
private func automationPermission(for bundleID: String, asking: Bool) async -> OSStatus {
    var target = AEAddressDesc()
    let bytes = Array(bundleID.utf8)
    guard AECreateDesc(typeApplicationBundleID, bytes, bytes.count, &target) == noErr else { return OSStatus(procNotFound) }
    defer { AEDisposeDesc(&target) }
    return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, asking)
}

struct PermissionsPane: View {
    @State private var accessibility: PermissionStatus = AXIsProcessTrusted() ? .allowed : .notAllowed
    @State private var systemEvents: PermissionStatus?
    @State private var finder: PermissionStatus?
    @State private var loginItem = PermissionStatus(loginItem: SMAppService.mainApp.status)

    var body: some View {
        Form {
            Section {
                PaneHeader(pane: .permissions)
            }
            Section {
                PermissionRow(title: "Accessibility", reason: "Lock Screen and media keys.", status: accessibility) {
                    if accessibility != .allowed {
                        Button("Allow…", action: requestAccessibility)
                    }
                }
            }
            Section {
                PermissionRow(title: "Automation: System Events", reason: "Restart, Shut Down, Log Out and Dark Mode.", status: systemEvents) {
                    automationButton(for: systemEventsID, status: systemEvents)
                }
            }
            Section {
                PermissionRow(title: "Automation: Finder", reason: "Trash and Eject.", status: finder) {
                    automationButton(for: finderID, status: finder)
                }
            }
            Section {
                PermissionRow(title: "Open at Login", reason: "Starts tinecast when you log in.", status: loginItem) {
                    if loginItem == .needsApproval {
                        Button("Open System Settings…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
    }

    @ViewBuilder private func automationButton(for bundleID: String, status: PermissionStatus?) -> some View {
        if status == .notSetUp {
            Button("Allow…") { Task { await requestAutomation(of: bundleID) } }
        } else if status == .notAllowed {
            Button("Open System Settings…") { NSWorkspace.shared.open(automationSettings) }
        }
    }

    private func refresh() async {
        accessibility = AXIsProcessTrusted() ? .allowed : .notAllowed
        loginItem = PermissionStatus(loginItem: SMAppService.mainApp.status)
        async let systemEventsStatus = automationPermission(for: systemEventsID, asking: false)
        async let finderStatus = automationPermission(for: finderID, asking: false)
        systemEvents = PermissionStatus(automation: await systemEventsStatus)
        finder = PermissionStatus(automation: await finderStatus)
    }

    private func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        NSWorkspace.shared.open(accessibilitySettings)
    }

    private func requestAutomation(of bundleID: String) async {
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        _ = await automationPermission(for: bundleID, asking: true)
        await refresh()
    }
}

private struct PermissionRow<Action: View>: View {
    let title: String
    let reason: String
    let status: PermissionStatus?
    @ViewBuilder let action: Action

    var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                action
                HStack(spacing: 4) {
                    if status == .allowed || status == .on {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                    }
                    Text(status?.title ?? "")
                        .foregroundStyle(status == .needsApproval ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                }
                .frame(width: 120, alignment: .trailing)
            }
            .lineLimit(1)
            .fixedSize()
        } label: {
            Text(title)
            Text(reason)
        }
    }
}
