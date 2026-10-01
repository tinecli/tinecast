import ApplicationServices
import ServiceManagement
import SwiftUI
import TinecastKit

private let systemEventsID = "com.apple.systemevents"
private let finderID = "com.apple.finder"
private let accessibilitySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
private let automationSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!

private enum Grant {
    case granted, notGranted, notDetermined

    init(_ status: OSStatus) {
        if status == noErr {
            self = .granted
        } else if status == OSStatus(errAEEventNotPermitted) {
            self = .notGranted
        } else {
            self = .notDetermined
        }
    }

    var status: (title: String, tone: Tone) {
        if self == .granted { return ("Granted", .ok) }
        if self == .notGranted { return ("Not Granted", .warning) }
        return ("Not Determined", .neutral)
    }
}

private enum Tone {
    case ok, warning, neutral
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
    let model: SettingsModel
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    @State private var systemEvents = Grant.notDetermined
    @State private var finder = Grant.notDetermined
    @State private var loginItem = SMAppService.mainApp.status
    @State private var isRefreshingRates = false
    @State private var ratesRefreshFailed = false

    var body: some View {
        Form {
            Section("Privacy & Security") {
                StatusRow(
                    title: "Accessibility",
                    systemImage: "accessibility",
                    detail: "Lets Lock Screen and the media actions send keystrokes.",
                    status: isAccessibilityTrusted ? ("Granted", .ok) : ("Not Granted", .warning)
                ) {
                    if !isAccessibilityTrusted {
                        Button("Grant Access…", action: requestAccessibility)
                    }
                }
                StatusRow(
                    title: "Automation: System Events",
                    systemImage: "gearshape.2",
                    detail: "Lets Restart, Shut Down, Log Out and Toggle Dark Mode run.",
                    status: systemEvents.status
                ) {
                    if systemEvents != .granted {
                        Button("Grant Access…") { Task { await requestAutomation(of: systemEventsID, current: systemEvents) } }
                    }
                }
                StatusRow(
                    title: "Automation: Finder",
                    systemImage: "finder",
                    detail: "Lets Empty Trash and Eject All Disks run.",
                    status: finder.status
                ) {
                    if finder != .granted {
                        Button("Grant Access…") { Task { await requestAutomation(of: finderID, current: finder) } }
                    }
                }
            }

            Section("Startup") {
                StatusRow(
                    title: "Open at login",
                    systemImage: "power",
                    detail: "Opens tinecast when you log in. Turn it on or off in General.",
                    status: loginItemStatus
                ) {
                    if loginItem == .requiresApproval {
                        Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                StatusRow(
                    title: "Hotkey",
                    systemImage: "keyboard",
                    detail: model.isHotkeyRegistered
                        ? "\(model.config.hotkey.glyphs) opens tinecast from any app."
                        : "Another app or a system shortcut already uses \(model.config.hotkey.glyphs). Choose another hotkey in General.",
                    status: model.isHotkeyRegistered ? ("Registered", .ok) : ("Unavailable", .warning)
                ) {}
            }

            Section("Data") {
                StatusRow(
                    title: "Exchange Rates",
                    systemImage: "eurosign.circle",
                    detail: ratesDetail,
                    status: ratesStatus
                ) {
                    if isRefreshingRates {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing")
                    }
                    Button("Refresh Now", action: refreshRates)
                        .disabled(isRefreshingRates)
                }
            }
        }
        .formStyle(.grouped)
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
    }

    private var loginItemStatus: (title: String, tone: Tone) {
        if loginItem == .enabled { return ("Enabled", .ok) }
        if loginItem == .requiresApproval { return ("Requires Approval", .warning) }
        if loginItem == .notRegistered { return ("Not Registered", .neutral) }
        return ("Not Found", .warning)
    }

    private var ratesStatus: (title: String, tone: Tone) {
        guard let rates = model.exchangeRates else { return ("Not Downloaded", .warning) }
        return rates.isStale(at: .now) ? ("Out of Date", .warning) : ("Up to Date", .ok)
    }

    private var ratesDetail: String {
        let failure = ratesRefreshFailed ? " The last update failed; check your internet connection." : ""
        guard let rates = model.exchangeRates else { return "Currency conversion uses the European Central Bank's reference rates." + failure }
        let rateDate = (try? Date.ISO8601FormatStyle().year().month().day().parse(rates.date))?.formatted(date: .long, time: .omitted) ?? rates.date
        return "ECB reference rates from \(rateDate), downloaded \(rates.fetchedAt.formatted(.relative(presentation: .named)))." + failure
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

    private func requestAutomation(of bundleID: String, current: Grant) async {
        guard current == .notDetermined else {
            NSWorkspace.shared.open(automationSettings)
            return
        }
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        _ = await automationPermission(for: bundleID, asking: true)
        await refresh()
    }

    private func refreshRates() {
        isRefreshingRates = true
        Task {
            ratesRefreshFailed = !(await model.refreshRates())
            isRefreshingRates = false
        }
    }
}

private struct StatusRow<Actions: View>: View {
    let title: String
    let systemImage: String
    let detail: String
    let status: (title: String, tone: Tone)
    @ViewBuilder let actions: Actions

    var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                Label {
                    Text(status.title)
                } icon: {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(statusColor)
                }
                .accessibilityLabel("\(title): \(status.title)")
                actions
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }

    private var statusSymbol: String {
        if status.tone == .ok { return "checkmark.circle.fill" }
        if status.tone == .warning { return "exclamationmark.triangle.fill" }
        return "questionmark.circle.fill"
    }

    private var statusColor: Color {
        if status.tone == .ok { return .green }
        if status.tone == .warning { return .orange }
        return .secondary
    }
}
