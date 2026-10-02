#if DEBUG
import AppKit

struct SettingsSnapshot {
    static let requested = SettingsSnapshot()

    let output: URL
    let pane: Pane

    private init?() {
        guard let path = UserDefaults.standard.string(forKey: "settingsSnapshot") else { return nil }
        output = URL(filePath: path)
        pane = UserDefaults.standard.string(forKey: "settingsPane").flatMap(Pane.init(rawValue:)) ?? .general
    }

    func capture() async {
        if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        let window = await Self.settingsWindow()
        window.setFrameAutosaveName("")
        window.isRestorable = false
        window.setFrameOrigin(NSPoint(x: -4000, y: 0))
        try? await Task.sleep(for: .seconds(1.5))
        if let image = Self.windowImage(window) {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: output)
        }
        NSApp.terminate(nil)
    }

    // cacheDisplay skips Liquid Glass; CGWindowListCreateImage is SDK-obsoleted but still exported and captures own windows without Screen Recording.
    private static func windowImage(_ window: NSWindow) -> CGImage? {
        typealias CreateImage = @convention(c) (CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        let create = unsafeBitCast(symbol, to: CreateImage.self)
        return create(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution])?.takeRetainedValue()
    }

    private static func settingsWindow() async -> NSWindow {
        while true {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("settings") == true }) { return window }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
#endif
