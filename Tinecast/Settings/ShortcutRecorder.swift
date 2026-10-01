import Carbon.HIToolbox
import SwiftUI
import TinecastKit

struct ShortcutRecorder: View {
    private static let modifiers: [(flag: NSEvent.ModifierFlags, carbon: Int)] = [
        (.control, controlKey), (.option, optionKey), (.shift, shiftKey), (.command, cmdKey),
    ]

    @Binding var combination: KeyCombination
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                if monitor == nil { startRecording() } else { stopRecording() }
            } label: {
                Text(monitor == nil ? combination.glyphs : "Type Shortcut")
                    .frame(minWidth: 96)
            }
            .accessibilityLabel("Hotkey")
            .accessibilityValue(monitor == nil ? combination.displayName : "Recording")
            .accessibilityHint(monitor == nil ? "Press to record a new hotkey." : "Press a key combination with at least one modifier, or Escape to cancel.")
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        hint = "Press a combination, or Esc to cancel."
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { record(event) }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hint = nil
    }

    private func record(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbonModifiers = Self.modifiers.filter { flags.contains($0.flag) }.reduce(0) { $0 | $1.carbon }
        if Int(event.keyCode) == kVK_Escape, carbonModifiers == 0 {
            stopRecording()
            return
        }
        guard carbonModifiers != 0 else {
            hint = "Include at least one modifier: ⌃, ⌥, ⇧ or ⌘."
            return
        }
        guard let recorded = KeyCombination(keyCode: Int(event.keyCode), carbonModifiers: carbonModifiers) else {
            hint = "Use a letter, number, Space, Return, Tab or F1–F12."
            return
        }
        combination = recorded
        stopRecording()
        AccessibilityNotification.Announcement("Hotkey set to \(recorded.displayName)").post()
    }
}
