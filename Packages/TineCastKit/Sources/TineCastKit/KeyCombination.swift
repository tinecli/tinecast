import Carbon.HIToolbox
import Foundation

public struct KeyCombination: Codable, Equatable, Sendable, CustomStringConvertible {
    private static let modifiers: [(names: Set<String>, token: String, displayName: String, glyph: String, carbonFlag: Int, eventFlag: Int)] = [
        (["ctrl", "control"], "ctrl", "Control", "⌃", controlKey, 0x40000),
        (["opt", "option", "alt"], "opt", "Option", "⌥", optionKey, 0x80000),
        (["shift"], "shift", "Shift", "⇧", shiftKey, 0x20000),
        (["cmd", "command"], "cmd", "Command", "⌘", cmdKey, 0x100000),
    ]
    private static let systemShortcuts: [(id: String, owner: String, keyCode: Int, eventFlags: Int)] = [
        ("60", "Input Sources", kVK_Space, 0x40000),
        ("61", "Input Sources", kVK_Space, 0xC0000),
        ("64", "Spotlight", kVK_Space, 0x100000),
        ("65", "Spotlight", kVK_Space, 0x180000),
    ]
    private static let keyGlyphs = ["return": "↩", "tab": "⇥"]

    private static let keys: [String: (keyCode: Int, displayName: String)] = [
        "space": (kVK_Space, "Space"), "return": (kVK_Return, "Return"), "tab": (kVK_Tab, "Tab"),
        "a": (kVK_ANSI_A, "A"), "b": (kVK_ANSI_B, "B"), "c": (kVK_ANSI_C, "C"), "d": (kVK_ANSI_D, "D"),
        "e": (kVK_ANSI_E, "E"), "f": (kVK_ANSI_F, "F"), "g": (kVK_ANSI_G, "G"), "h": (kVK_ANSI_H, "H"),
        "i": (kVK_ANSI_I, "I"), "j": (kVK_ANSI_J, "J"), "k": (kVK_ANSI_K, "K"), "l": (kVK_ANSI_L, "L"),
        "m": (kVK_ANSI_M, "M"), "n": (kVK_ANSI_N, "N"), "o": (kVK_ANSI_O, "O"), "p": (kVK_ANSI_P, "P"),
        "q": (kVK_ANSI_Q, "Q"), "r": (kVK_ANSI_R, "R"), "s": (kVK_ANSI_S, "S"), "t": (kVK_ANSI_T, "T"),
        "u": (kVK_ANSI_U, "U"), "v": (kVK_ANSI_V, "V"), "w": (kVK_ANSI_W, "W"), "x": (kVK_ANSI_X, "X"),
        "y": (kVK_ANSI_Y, "Y"), "z": (kVK_ANSI_Z, "Z"),
        "0": (kVK_ANSI_0, "0"), "1": (kVK_ANSI_1, "1"), "2": (kVK_ANSI_2, "2"), "3": (kVK_ANSI_3, "3"),
        "4": (kVK_ANSI_4, "4"), "5": (kVK_ANSI_5, "5"), "6": (kVK_ANSI_6, "6"), "7": (kVK_ANSI_7, "7"),
        "8": (kVK_ANSI_8, "8"), "9": (kVK_ANSI_9, "9"),
        "f1": (kVK_F1, "F1"), "f2": (kVK_F2, "F2"), "f3": (kVK_F3, "F3"), "f4": (kVK_F4, "F4"),
        "f5": (kVK_F5, "F5"), "f6": (kVK_F6, "F6"), "f7": (kVK_F7, "F7"), "f8": (kVK_F8, "F8"),
        "f9": (kVK_F9, "F9"), "f10": (kVK_F10, "F10"), "f11": (kVK_F11, "F11"), "f12": (kVK_F12, "F12"),
    ]

    public let keyCode: Int
    public let carbonModifiers: Int
    public let displayName: String
    public let keycaps: [String]
    public let glyphs: String
    public let description: String

    public init?(_ text: String) {
        let parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyName = parts.last, let key = Self.keys[keyName] else { return nil }
        let modifierNames = Set(parts.dropLast())
        let used = Self.modifiers.filter { !$0.names.isDisjoint(with: modifierNames) }
        let known = used.reduce(into: Set<String>()) { $0.formUnion($1.names) }
        guard !used.isEmpty, modifierNames.isSubset(of: known) else { return nil }

        keyCode = key.keyCode
        carbonModifiers = used.reduce(0) { $0 | $1.carbonFlag }
        displayName = (used.map(\.displayName) + [key.displayName]).joined(separator: "-")
        keycaps = used.map(\.glyph) + [Self.keyGlyphs[keyName] ?? key.displayName]
        glyphs = keycaps.joined()
        description = (used.map(\.token) + [keyName]).joined(separator: "+")
    }

    public init?(keyCode: Int, carbonModifiers: Int) {
        guard let keyName = Self.keys.first(where: { $0.value.keyCode == keyCode })?.key else { return nil }
        let tokens = Self.modifiers.filter { carbonModifiers & $0.carbonFlag != 0 }.map(\.token)
        self.init((tokens + [keyName]).joined(separator: "+"))
    }

    public func systemShortcutOwner(in symbolicHotKeys: [String: Any]) -> String? {
        let eventFlags = Self.modifiers.filter { carbonModifiers & $0.carbonFlag != 0 }.reduce(0) { $0 | $1.eventFlag }
        return Self.systemShortcuts.first { shortcut in
            guard let entry = symbolicHotKeys[shortcut.id] as? [String: Any] else {
                return shortcut.keyCode == keyCode && shortcut.eventFlags == eventFlags
            }
            let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [Int]
            return entry["enabled"] as? Int == 1 && parameters.map { Array($0.dropFirst()) } == [keyCode, eventFlags]
        }?.owner
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let combination = KeyCombination(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "\"\(text)\" isn't a key combination TineCast understands, try something like \"ctrl+space\".")
        }
        self = combination
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
