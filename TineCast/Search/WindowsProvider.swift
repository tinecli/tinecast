import AppKit
import ApplicationServices

nonisolated struct AppWindow: Sendable {
    let pid: pid_t
    let windowID: CGWindowID
    let title: String
    let isMinimized: Bool
    let isOnOtherSpace: Bool
}

private typealias GetWindowFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
private typealias CreateWithRemoteTokenFunction = @convention(c) (CFData) -> UnsafeMutableRawPointer?
private typealias GetProcessForPIDFunction = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
private typealias SetFrontProcessFunction = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
private typealias PostEventRecordFunction = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
private typealias PrivateAPI = (
    getWindow: GetWindowFunction,
    createWithRemoteToken: CreateWithRemoteTokenFunction,
    getProcessForPID: GetProcessForPIDFunction,
    setFrontProcess: SetFrontProcessFunction,
    postEventRecord: PostEventRecordFunction
)

nonisolated private let privateAPI: PrivateAPI? = {
    guard let services = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY),
          let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
          let getWindow = dlsym(services, "_AXUIElementGetWindow"),
          let createWithRemoteToken = dlsym(services, "_AXUIElementCreateWithRemoteToken"),
          let getProcessForPID = dlsym(services, "GetProcessForPID"),
          let setFrontProcess = dlsym(skyLight, "_SLPSSetFrontProcessWithOptions"),
          let postEventRecord = dlsym(skyLight, "SLPSPostEventRecordTo")
    else { return nil }
    return (
        getWindow: unsafeBitCast(getWindow, to: GetWindowFunction.self),
        createWithRemoteToken: unsafeBitCast(createWithRemoteToken, to: CreateWithRemoteTokenFunction.self),
        getProcessForPID: unsafeBitCast(getProcessForPID, to: GetProcessForPIDFunction.self),
        setFrontProcess: unsafeBitCast(setFrontProcess, to: SetFrontProcessFunction.self),
        postEventRecord: unsafeBitCast(postEventRecord, to: PostEventRecordFunction.self)
    )
}()

let listsWindowsOnAllSpaces = privateAPI != nil

@concurrent
func appWindows(of pid: pid_t) async -> [AppWindow] {
    standardWindows(of: pid).map { $0.window }
}

@concurrent
func raiseWindow(pid: pid_t, windowID: CGWindowID) async {
    guard let match = standardWindows(of: pid).first(where: { $0.window.windowID == windowID }) else {
        NSRunningApplication(processIdentifier: pid)?.activate()
        return
    }
    if match.window.isMinimized {
        AXUIElementSetAttributeValue(match.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }
    guard let privateAPI else {
        AXUIElementPerformAction(match.element, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: pid)?.activate()
        return
    }
    var process = ProcessSerialNumber()
    _ = privateAPI.getProcessForPID(pid, &process)
    // 0x200 is kCPSUserGenerated; passing the window id fronts only that window and switches to its Space.
    _ = privateAPI.setFrontProcess(&process, windowID, 0x200)
    // CGSEventRecord left-mouse-down (yabai/AltTab layout): length 0xf8 at 0x04, type at 0x08, point at 0x20, flag 0x10 at 0x3a, window id at 0x3c.
    var event = [UInt8](repeating: 0, count: 0x100)
    event[0x04] = 0xf8
    event[0x08] = 0x01
    event[0x3a] = 0x10
    withUnsafeBytes(of: CGPoint(x: 300_000, y: 300_000)) { event.replaceSubrange(0x20..<0x30, with: $0) }
    withUnsafeBytes(of: windowID) { event.replaceSubrange(0x3c..<0x40, with: $0) }
    _ = privateAPI.postEventRecord(&process, &event)
    AXUIElementPerformAction(match.element, kAXRaiseAction as CFString)
}

private nonisolated func standardWindows(of pid: pid_t) -> [(element: AXUIElement, window: AppWindow)] {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.25)
    let current = (attribute(kAXWindowsAttribute, of: app) as? [AnyObject] ?? [])
        .filter { CFGetTypeID($0) == AXUIElementGetTypeID() }
        .map { $0 as! AXUIElement }
        .filter { attribute(kAXSubroleAttribute, of: $0) as? String == kAXStandardWindowSubrole }
    let found: [(element: AXUIElement, windowID: CGWindowID, isOnCurrentSpace: Bool)]
    if let privateAPI {
        let listed = current.compactMap { element -> (element: AXUIElement, windowID: CGWindowID, isOnCurrentSpace: Bool)? in
            var windowID = CGWindowID(0)
            return privateAPI.getWindow(element, &windowID) == .success ? (element, windowID, true) : nil
        }
        found = listed + otherSpaceWindows(of: pid, excluding: Set(listed.map { $0.windowID }), using: privateAPI)
    } else {
        // Without _AXUIElementGetWindow the list position stands in for the window id.
        found = current.enumerated().map { index, element in (element, CGWindowID(index), true) }
    }
    return found.map { candidate in
        let isMinimized = attribute(kAXMinimizedAttribute, of: candidate.element) as? Bool ?? false
        return (element: candidate.element, window: AppWindow(
            pid: pid,
            windowID: candidate.windowID,
            title: attribute(kAXTitleAttribute, of: candidate.element) as? String ?? "",
            isMinimized: isMinimized,
            isOnOtherSpace: !candidate.isOnCurrentSpace && !isMinimized
        ))
    }
}

private nonisolated func otherSpaceWindows(of pid: pid_t, excluding listed: Set<CGWindowID>, using privateAPI: PrivateAPI) -> [(element: AXUIElement, windowID: CGWindowID, isOnCurrentSpace: Bool)] {
    let windowInfo = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    var remaining = Set(windowInfo
        .filter { $0[kCGWindowOwnerPID as String] as? pid_t == pid && $0[kCGWindowLayer as String] as? Int == 0 }
        .compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        .subtracting(listed)
    var found: [(element: AXUIElement, windowID: CGWindowID, isOnCurrentSpace: Bool)] = []
    // Remote token: pid (4 bytes), 0 (4), "coco" magic 0x636f636f (4), AXUIElementID (8).
    var token = Data(count: 20)
    token.withUnsafeMutableBytes { bytes in
        bytes.storeBytes(of: pid, toByteOffset: 0, as: pid_t.self)
        bytes.storeBytes(of: Int32(0x636f636f), toByteOffset: 8, as: Int32.self)
    }
    let deadline = Date.now.addingTimeInterval(0.25)
    for elementID in UInt64(0)..<UInt64.max {
        guard !remaining.isEmpty, Date.now < deadline else { break }
        token.withUnsafeMutableBytes { $0.storeBytes(of: elementID, toByteOffset: 12, as: UInt64.self) }
        guard let created = privateAPI.createWithRemoteToken(token as CFData) else { continue }
        let element = Unmanaged<AXUIElement>.fromOpaque(created).takeRetainedValue()
        AXUIElementSetMessagingTimeout(element, 0.25)
        var windowID = CGWindowID(0)
        guard privateAPI.getWindow(element, &windowID) == .success,
              remaining.contains(windowID),
              attribute(kAXRoleAttribute, of: element) as? String == kAXWindowRole
        else { continue }
        remaining.remove(windowID)
        guard attribute(kAXSubroleAttribute, of: element) as? String == kAXStandardWindowSubrole else { continue }
        found.append((element, windowID, false))
    }
    return found
}

private nonisolated func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
