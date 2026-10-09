#if DEBUG
import AppKit
import TineCastKit

struct PanelSnapshot {
    static let requested = PanelSnapshot()

    let output: URL

    private init?() {
        guard let path = UserDefaults.standard.string(forKey: "panelSnapshot") else { return nil }
        output = URL(filePath: path, directoryHint: .isDirectory)
    }

    func capture(_ controller: PanelController) async {
        if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        let model = controller.model
        while model.apps.alphabetical.isEmpty { try? await Task.sleep(for: .milliseconds(50)) }
        let command = Command(name: "Deploy Preview", command: "true")
        var config = Config()
        config.commands = [command]
        config.aliases = [command.item.id: "dp", model.apps.alphabetical[0].id: "first"]
        model.config = config
        model.frecency.record(query: "", itemID: command.item.id, at: .now)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        controller.toggle()
        await save("open1")
        controller.toggle()
        try? await Task.sleep(for: .seconds(0.5))
        controller.toggle()
        await save("open2")
        controller.hide()
        try? await Task.sleep(for: .seconds(0.5))
        controller.toggle()
        await save("open3")
        exit(0)
    }

    private func save(_ name: String) async {
        try? await Task.sleep(for: .seconds(1))
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }),
              let image = SettingsSnapshot.image(of: panel, bounds: panel.frame, options: [.optionIncludingWindow, .optionOnScreenBelowWindow])
        else { return }
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: output.appending(path: "\(name).png"))
    }
}
#endif
