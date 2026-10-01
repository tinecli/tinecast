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
            Section {
                StatusRow(
                    title: "Accessibility",
                    tile: ("accessibility", .blue),
                    status: isAccessibilityTrusted ? ("Granted", .ok) : ("Not Granted", .warning)
                ) {
                    if !isAccessibilityTrusted {
                        Button("Grant Access…", action: requestAccessibility)
                    }
                }
                StatusRow(
                    title: "Automation: System Events",
                    tile: ("gearshape.2.fill", .gray),
                    status: systemEvents.status
                ) {
                    if systemEvents != .granted {
                        Button("Grant Access…") { Task { await requestAutomation(of: systemEventsID, current: systemEvents) } }
                    }
                }
                StatusRow(
                    title: "Automation: Finder",
                    tile: ("finder", .cyan),
                    status: finder.status
                ) {
                    if finder != .granted {
                        Button("Grant Access…") { Task { await requestAutomation(of: finderID, current: finder) } }
                    }
                }
            } header: {
                Text("Privacy & Security")
            } footer: {
                Text("System actions such as Lock Screen, Restart and Empty Trash need these.")
                    .foregroundStyle(.secondary)
            }

            Section {
                StatusRow(
                    title: "Login Item",
                    tile: ("power", .green),
                    status: loginItemStatus
                ) {
                    if loginItem == .requiresApproval {
                        Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                StatusRow(
                    title: "Hotkey",
                    tile: ("keyboard", .gray),
                    status: model.isHotkeyRegistered ? ("Registered", .ok) : ("Unavailable", .warning)
                ) {}
            } header: {
                Text("Startup")
            } footer: {
                if !model.isHotkeyRegistered {
                    Text("Another app or a system shortcut already uses \(model.config.hotkey.glyphs). Choose another hotkey in General.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                StatusRow(
                    title: "Exchange Rates",
                    tile: ("eurosign", .teal),
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
            } header: {
                Text("Data")
            } footer: {
                Text(ratesDetail)
                    .foregroundStyle(.secondary)
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
        let failure = ratesRefreshFailed ? " The last update failed." : ""
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
    let tile: (symbol: String, color: Color)
    let status: (title: String, tone: Tone)
    @ViewBuilder let actions: Actions

    var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                Label {
                    Text(status.title)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(statusColor)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(title): \(status.title)")
                actions
            }
        } label: {
            Label { Text(title) } icon: { Tile(symbol: tile.symbol, color: tile.color) }
        }
    }

    private var statusSymbol: String {
        if status.tone == .ok { return "checkmark.circle.fill" }
        if status.tone == .warning { return "exclamationmark.triangle.fill" }
        return "questionmark.circle"
    }

    private var statusColor: Color {
        if status.tone == .ok { return .green }
        if status.tone == .warning { return .orange }
        return .secondary
    }
}
