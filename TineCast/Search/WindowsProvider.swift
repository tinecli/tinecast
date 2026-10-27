import ApplicationServices

nonisolated struct AppWindow: Sendable {
    let pid: pid_t
    let index: Int
    let title: String
    let isMinimized: Bool
}

@concurrent
func appWindows(of pid: pid_t) async -> [AppWindow] {
    standardWindows(of: pid).map { $0.window }
}

func raiseWindow(pid: pid_t, index: Int, title: String) {
    let windows = standardWindows(of: pid)
    let match = windows.first { $0.window.index == index && $0.window.title == title }
        ?? windows.first { $0.window.title == title }
        ?? windows.first { $0.window.index == index }
    guard let match else { return }
    if match.window.isMinimized {
        AXUIElementSetAttributeValue(match.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }
    AXUIElementPerformAction(match.element, kAXRaiseAction as CFString)
}

private nonisolated func standardWindows(of pid: pid_t) -> [(element: AXUIElement, window: AppWindow)] {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.25)
    let elements = (attribute(kAXWindowsAttribute, of: app) as? [AnyObject] ?? [])
        .filter { CFGetTypeID($0) == AXUIElementGetTypeID() }
        .map { $0 as! AXUIElement }
        .filter { attribute(kAXSubroleAttribute, of: $0) as? String == kAXStandardWindowSubrole }
    return elements.enumerated().map { index, element in
        (element: element, window: AppWindow(
            pid: pid,
            index: index,
            title: attribute(kAXTitleAttribute, of: element) as? String ?? "",
            isMinimized: attribute(kAXMinimizedAttribute, of: element) as? Bool ?? false
        ))
    }
}

private nonisolated func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
