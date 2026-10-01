import ApplicationServices
import ServiceManagement
import SwiftUI

private let systemEventsID = "com.apple.systemevents"
private let finderID = "com.apple.finder"
private let accessibilitySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
private let automationSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!

private struct Status {
    static let allowed = Status(title: "Allowed", symbol: "checkmark.circle.fill", tint: .green)
    static let notAllowed = Status(title: "Not Allowed")
    static let notSetUp = Status(title: "Not Set Up")
    static let on = Status(title: "On", symbol: "checkmark.circle.fill", tint: .green)
    static let off = Status(title: "Off")
    static let needsApproval = Status(title: "Needs Approval", symbol: "exclamationmark.triangle.fill", tint: .orange)

    let title: String
    var symbol: String?
    var tint = Color.secondary
}

private enum Grant {
    case allowed, notAllowed, notSetUp

    init(_ status: OSStatus) {
        if status == noErr {
            self = .allowed
        } else if status == OSStatus(errAEEventNotPermitted) {
            self = .notAllowed
        } else {
            self = .notSetUp
        }
    }

    var status: Status {
        if self == .allowed { return .allowed }
        if self == .notAllowed { return .notAllowed }
        return .notSetUp
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

struct PermissionsSettings: View {
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    @State private var systemEvents = Grant.notSetUp
    @State private var finder = Grant.notSetUp
    @State private var loginItem = SMAppService.mainApp.status

    var body: some View {
        Form {
            Section {
                PermissionRow(title: "Accessibility", reason: "Needed for Lock Screen.", status: isAccessibilityTrusted ? .allowed : .notAllowed) {
                    if !isAccessibilityTrusted {
                        Button("Allow…", action: requestAccessibility)
                    }
                }
            }
            Section {
                PermissionRow(title: "Automation: System Events", reason: "For Restart, Shut Down and Log Out.", status: systemEvents.status) {
                    automationButton(for: systemEventsID, current: systemEvents)
                }
            }
            Section {
                PermissionRow(title: "Automation: Finder", reason: "For Empty Trash and Eject All Disks.", status: finder.status) {
                    automationButton(for: finderID, current: finder)
                }
            }
            Section {
                PermissionRow(title: "Open at Login", reason: "Starts tinecast when you log in.", status: loginStatus) {
                    if loginItem == .requiresApproval {
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

    private var loginStatus: Status {
        if loginItem == .enabled { return .on }
        if loginItem == .requiresApproval { return .needsApproval }
        return .off
    }

    @ViewBuilder private func automationButton(for bundleID: String, current: Grant) -> some View {
        if current == .notSetUp {
            Button("Allow…") { Task { await requestAutomation(of: bundleID) } }
        } else if current == .notAllowed {
            Button("Open System Settings…") { NSWorkspace.shared.open(automationSettings) }
        }
    }

    private func refresh() async {
        isAccessibilityTrusted = AXIsProcessTrusted()
        loginItem = SMAppService.mainApp.status
        systemEvents = Grant(await automationPermission(for: systemEventsID, asking: false))
        finder = Grant(await automationPermission(for: finderID, asking: false))
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
    let status: Status
    @ViewBuilder let action: Action

    var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                action
                Label {
                    Text(status.title)
                } icon: {
                    Image(systemName: status.symbol ?? "circle")
                        .foregroundStyle(status.tint)
                        .opacity(status.symbol == nil ? 0 : 1)
                }
                .foregroundStyle(.secondary)
                .frame(minWidth: 124, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(status.title)
            }
            .lineLimit(1)
            .fixedSize()
        } label: {
            Text(title)
            Text(reason)
        }
        .lineLimit(1)
    }
}
