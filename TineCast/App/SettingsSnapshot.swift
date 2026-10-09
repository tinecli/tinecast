#if DEBUG
import AppKit
import TineCastKit

struct SettingsSnapshot {
    enum Presentation: String {
        case editor, picker
    }

    static let requested = SettingsSnapshot()

    let output: URL
    let windowID: String
    let pane: Pane
    let config: Config?
    let presentation: Presentation?
    let search: String?
    let reveal: Int?

    private init?() {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: "settingsSnapshot") else { return nil }
        output = URL(filePath: path)
        let paneName = defaults.string(forKey: "settingsPane")
        windowID = paneName == "welcome" ? "welcome" : "settings"
        pane = paneName.flatMap(Pane.init(rawValue:)) ?? .general
        config = defaults.string(forKey: "settingsConfig").flatMap { try? Config(json: Data(contentsOf: URL(filePath: $0))) }
        presentation = defaults.string(forKey: "settingsPresent").flatMap(Presentation.init(rawValue:))
        search = defaults.string(forKey: "settingsSearch")
        reveal = defaults.object(forKey: "settingsReveal") == nil ? nil : defaults.integer(forKey: "settingsReveal")
    }

    func capture() async {
        if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        let window = await Self.window(id: windowID)
        window.setFrameAutosaveName("")
        window.isRestorable = false
        if presentation != .picker { window.setFrameOrigin(NSPoint(x: -4000, y: 0)) }
        try? await Task.sleep(for: .seconds(1.5))
        let target = switch presentation {
        case .editor: window.attachedSheet
        case .picker: NSApp.windows.first { $0.isVisible && $0.className.contains("Popover") }
        case nil: window
        }
        guard let target else { exit(1) }
        let image = presentation == .picker
            ? Self.image(of: target, bounds: target.frame, options: [.optionIncludingWindow, .optionOnScreenBelowWindow])
            : Self.image(of: target, bounds: nil, options: .optionIncludingWindow)
        if let image {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: output)
        }
        exit(0)
    }

    // cacheDisplay skips Liquid Glass; CGWindowListCreateImage is SDK-obsoleted but still exported and captures own windows without Screen Recording.
    static func image(of window: NSWindow, bounds frame: NSRect?, options: CGWindowListOption) -> CGImage? {
        typealias CreateImage = @convention(c) (CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage"), let screen = NSScreen.screens.first else { return nil }
        let create = unsafeBitCast(symbol, to: CreateImage.self)
        let bounds = frame.map { CGRect(x: $0.minX, y: screen.frame.maxY - $0.maxY, width: $0.width, height: $0.height) } ?? .null
        return create(bounds, options, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution])?.takeRetainedValue()
    }

    private static func window(id: String) async -> NSWindow {
        while true {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix(id) == true }) { return window }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
#endif
