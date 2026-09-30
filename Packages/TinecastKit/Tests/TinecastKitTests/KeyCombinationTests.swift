import Carbon.HIToolbox
import Testing
import TinecastKit

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
