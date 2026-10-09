import Carbon.HIToolbox
import Testing
import TineCastKit

@Test func parsesTheDocumentedHotkeys() throws {
    let controlSpace = try #require(KeyCombination("ctrl+space"))
    let commandSpace = try #require(KeyCombination("cmd+space"))
    let optionSpace = try #require(KeyCombination("opt+space"))

    #expect(controlSpace.keyCode == kVK_Space)
    #expect(controlSpace.carbonModifiers == controlKey)
    #expect(commandSpace.carbonModifiers == cmdKey)
    #expect(optionSpace.carbonModifiers == optionKey)
    #expect(controlSpace.displayName == "Control-Space")
    #expect(commandSpace.displayName == "Command-Space")
}

@Test func acceptsAliasesCaseAndSpacingInAnyOrder() {
    let canonical = KeyCombination("ctrl+opt+shift+cmd+k")

    #expect(canonical != nil)
    #expect(KeyCombination("Command + Shift + Option + Control + K") == canonical)
    #expect(KeyCombination("cmd+alt+shift+control+k") == canonical)
    #expect(canonical?.description == "ctrl+opt+shift+cmd+k")
    #expect(canonical?.displayName == "Control-Option-Shift-Command-K")
    #expect(canonical?.carbonModifiers == controlKey | optionKey | shiftKey | cmdKey)
}

@Test func rejectsMissingModifiersUnknownTokensAndGarbage() {
    #expect(KeyCombination("space") == nil)
    #expect(KeyCombination("ctrl+spacebar") == nil)
    #expect(KeyCombination("hyper+space") == nil)
    #expect(KeyCombination("ctrl+") == nil)
    #expect(KeyCombination("+space") == nil)
    #expect(KeyCombination("") == nil)
}

@Test func roundTripsAsItsCanonicalString() throws {
    let combination = try #require(KeyCombination("Control+F5"))
    let encoded = try JSONEncoder().encode([combination])

    #expect(String(decoding: encoded, as: UTF8.self) == #"["ctrl+f5"]"#)
    #expect(try JSONDecoder().decode([KeyCombination].self, from: encoded) == [combination])
}

@Test func showsStandardGlyphsInMenuOrder() {
    #expect(KeyCombination("ctrl+space")?.glyphs == "⌃Space")
    #expect(KeyCombination("cmd+shift+opt+ctrl+k")?.glyphs == "⌃⌥⇧⌘K")
    #expect(KeyCombination("cmd+return")?.glyphs == "⌘↩")
    #expect(KeyCombination("opt+tab")?.glyphs == "⌥⇥")
}

@Test func buildsFromARecordedKeyCodeAndModifiers() {
    #expect(KeyCombination(keyCode: kVK_Space, carbonModifiers: controlKey) == KeyCombination("ctrl+space"))
    #expect(KeyCombination(keyCode: kVK_ANSI_K, carbonModifiers: cmdKey | shiftKey) == KeyCombination("shift+cmd+k"))
    #expect(KeyCombination(keyCode: kVK_Space, carbonModifiers: 0) == nil)
    #expect(KeyCombination(keyCode: kVK_LeftArrow, carbonModifiers: controlKey) == nil)
}

@Test func splitsIntoOneKeycapPerModifierAndKey() {
    #expect(KeyCombination("cmd+shift+f12")?.keycaps == ["⇧", "⌘", "F12"])
    #expect(KeyCombination("ctrl+space")?.keycaps == ["⌃", "Space"])
    #expect(KeyCombination("opt+return")?.keycaps == ["⌥", "↩"])
}

@Test func findsTheSystemShortcutThatOwnsACombination() throws {
    let controlSpace = try #require(KeyCombination("ctrl+space"))
    let commandSpace = try #require(KeyCombination("cmd+space"))
    let optionSpace = try #require(KeyCombination("opt+space"))
    let remapped: [String: Any] = [
        "60": ["enabled": 1, "value": ["parameters": [32, 49, 0x80000], "type": "standard"]],
        "64": ["enabled": 0, "value": ["parameters": [32, 49, 0x100000], "type": "standard"]],
    ]

    #expect(controlSpace.systemShortcutOwner(in: [:]) == "Input Sources")
    #expect(commandSpace.systemShortcutOwner(in: [:]) == "Spotlight")
    #expect(controlSpace.systemShortcutOwner(in: remapped) == nil)
    #expect(commandSpace.systemShortcutOwner(in: remapped) == nil)
    #expect(optionSpace.systemShortcutOwner(in: remapped) == "Input Sources")
    #expect(KeyCombination("ctrl+opt+k")?.systemShortcutOwner(in: [:]) == nil)
}
