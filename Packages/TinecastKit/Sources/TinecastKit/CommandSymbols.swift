public struct SymbolGroup: Sendable {
    public let title: String
    public let symbols: [String]

    public init(title: String, symbols: [String]) {
        self.title = title
        self.symbols = symbols
    }
}

public let commandSymbolGroups = [
    SymbolGroup(title: "Code", symbols: [
        "terminal", "apple.terminal", "chevron.left.forwardslash.chevron.right", "curlybraces", "number", "function",
        "hammer", "wrench.and.screwdriver", "screwdriver", "gearshape", "gearshape.2", "cpu", "memorychip",
        "server.rack", "externaldrive", "internaldrive", "ladybug", "ant", "testtube.2", "flask",
        "arrow.triangle.branch", "arrow.triangle.merge", "arrow.triangle.pull", "point.3.connected.trianglepath.dotted", "shippingbox", "cube",
    ]),
    SymbolGroup(title: "Files", symbols: [
        "doc", "doc.text", "doc.on.doc", "doc.zipper", "doc.badge.plus", "folder", "folder.badge.plus",
        "archivebox", "tray", "tray.full", "tray.and.arrow.down", "tray.and.arrow.up", "paperclip", "link",
        "square.and.arrow.up", "square.and.arrow.down", "arrow.down.doc", "trash", "xmark.bin", "printer",
        "scissors", "list.bullet", "list.clipboard", "note.text", "book", "bookmark",
    ]),
    SymbolGroup(title: "Network", symbols: [
        "network", "globe", "wifi", "antenna.radiowaves.left.and.right", "icloud", "icloud.and.arrow.up",
        "icloud.and.arrow.down", "arrow.down.circle", "arrow.up.circle", "arrow.clockwise", "arrow.triangle.2.circlepath",
        "arrow.up.arrow.down", "bolt.horizontal", "cable.connector", "personalhotspot", "lock.shield",
        "key", "lock", "lock.open", "shield", "checkmark.shield", "envelope", "paperplane", "bubble.left", "phone", "video",
    ]),
    SymbolGroup(title: "Media", symbols: [
        "play", "pause", "stop", "playpause", "forward", "backward", "shuffle", "repeat", "music.note",
        "music.note.list", "headphones", "speaker.wave.2", "speaker.slash", "mic", "mic.slash", "camera",
        "photo", "photo.on.rectangle", "film", "tv", "sparkles.tv", "waveform", "radio", "hifispeaker",
    ]),
    SymbolGroup(title: "Devices", symbols: [
        "desktopcomputer", "laptopcomputer", "macmini", "display", "display.2", "keyboard", "computermouse",
        "iphone", "ipad", "applewatch", "airpods", "gamecontroller", "battery.100percent", "powerplug",
        "power", "poweron", "lightbulb", "lamp.desk", "house", "sun.max", "moon", "cloud.sun",
    ]),
    SymbolGroup(title: "Objects", symbols: [
        "star", "heart", "flag", "tag", "bell", "pin", "mappin", "map", "location", "calendar", "clock", "timer",
        "stopwatch", "alarm", "hourglass", "cart", "bag", "creditcard", "gift", "briefcase", "graduationcap",
        "paintbrush", "paintpalette", "pencil", "eraser", "magnifyingglass", "eye", "eye.slash", "wand.and.stars",
        "sparkles", "bolt", "flame", "drop", "leaf", "pawprint", "cup.and.saucer", "fork.knife", "airplane", "car", "bicycle",
    ]),
    SymbolGroup(title: "Shapes", symbols: [
        "circle", "square", "triangle", "diamond", "hexagon", "seal", "checkmark.circle", "xmark.circle",
        "plus.circle", "minus.circle", "exclamationmark.triangle", "info.circle", "questionmark.circle",
        "arrow.right.circle", "chevron.right.2", "square.grid.2x2", "rectangle.stack", "slider.horizontal.3",
    ]),
]
