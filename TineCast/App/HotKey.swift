import Carbon.HIToolbox

final class HotKey {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().action() }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        guard installStatus == noErr else { return nil }

        let id = EventHotKeyID(signature: OSType(0x7463_6173), id: 1)
        let registerStatus = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registerStatus == noErr else { return nil }
    }

    isolated deinit {
        UnregisterEventHotKey(hotKeyRef)
        RemoveEventHandler(handlerRef)
    }
}
