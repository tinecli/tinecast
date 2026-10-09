import AppKit
import SwiftUI

struct WelcomeView: View {
    private static let completedKey = "TinecastWelcomeCompleted"
    private static let keyboardSettings = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!

    static var launchBehavior: SceneLaunchBehavior {
        #if DEBUG
        if let snapshot = SettingsSnapshot.requested { return snapshot.windowID == "welcome" ? .presented : .suppressed }
        if UserDefaults.standard.bool(forKey: "showWelcome") { return .presented }
        #endif
        return UserDefaults.standard.bool(forKey: completedKey) ? .suppressed : .presented
    }

    @Bindable var model: SettingsModel
    @State private var symbolicHotKeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Welcome to TineCast")
                .font(.largeTitle.bold())
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
            Text("Open apps, find files and run actions from one shortcut.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            SettingsCard {
                hotkeyRow
                WelcomeRow(title: "Open at Login", detail: "Start TineCast when you log in.") {
                    Toggle("Open at Login", isOn: $model.config.launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                WelcomeRow(title: "Optional Permissions", detail: "Accessibility is only needed for Lock Screen and media keys.") {
                    Button("Open Permissions…") {
                        model.requestedPane = .permissions
                        openWindow(id: "settings")
                    }
                }
            }
            .padding(.top, 24)
            Button {
                dismissWindow(id: "welcome")
                DispatchQueue.main.async { model.showPanel() }
            } label: {
                Text("Get Started")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 24)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .frame(width: 500)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .windowMinimizeBehavior(.disabled)
        .onAppear { NSApp.activate() }
        .onDisappear { UserDefaults.standard.set(true, forKey: Self.completedKey) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            symbolicHotKeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        }
    }

    private var hotkeyRow: some View {
        let hotkey = model.config.hotkey
        let owner = hotkey.systemShortcutOwner(in: symbolicHotKeys)
        return WelcomeRow(title: "Open TineCast with", detail: owner.map { "\(hotkey.glyphs) is used by \($0). Change it in System Settings › Keyboard › Keyboard Shortcuts › \($0)." }
            ?? (model.isHotkeyRegistered ? "Press it in any app." : "\(hotkey.glyphs) is used by another app. Choose another.")) {
            ShortcutRecorder(combination: $model.config.hotkey)
        } footer: {
            if owner != nil {
                Button("Open Keyboard Settings…") { NSWorkspace.shared.open(Self.keyboardSettings) }
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
    }
}

private struct WelcomeRow<Control: View, Footer: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control
    @ViewBuilder var footer: Footer

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                footer
            }
            Spacer(minLength: 0)
            control
        }
    }
}

extension WelcomeRow where Footer == EmptyView {
    init(title: String, detail: String, @ViewBuilder control: () -> Control) {
        self.init(title: title, detail: detail, control: control, footer: { EmptyView() })
    }
}
