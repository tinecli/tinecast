import AppKit

// Without a Dock icon, macOS leaves the menu bar blank after a Space switch while Settings or Welcome is key.
func hideDockIcon(unlessOpen windowID: String) {
    let isOpen = NSApp.windows.contains { ($0.isVisible || $0.isMiniaturized) && $0.identifier?.rawValue.hasPrefix(windowID) == true }
    if !isOpen { NSApp.setActivationPolicy(.accessory) }
}
