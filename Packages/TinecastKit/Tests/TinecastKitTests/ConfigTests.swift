import Foundation
import Testing
import TinecastKit

private func config(_ json: String) throws -> Config {
    try Config(json: Data(json.utf8))
}

private func problem(_ json: String) -> String? {
    do {
        _ = try Config(json: Data(json.utf8))
        return nil
    } catch {
        return error.errorDescription
    }
}

@Test func emptyObjectDecodesToDefaults() throws {
    let decoded = try config("{}")

    #expect(decoded == Config())
    #expect(decoded.hotkey == KeyCombination("ctrl+space"))
    #expect(!decoded.launchAtLogin)
    #expect(!decoded.compact)
    #expect(decoded.reopenTimeout == 90)
    #expect(decoded.fileSearch.folders == ["~"])
    #expect(decoded.fileSearch.exclusions == ["~/Library"])
    #expect(decoded.historyIgnore == nil)
}

@Test func presentKeysOverrideOnlyThemselves() throws {
    let decoded = try config(#"{ "hotkey": "cmd+space", "compact": true, "fileSearch": { "folders": ["~/Code"] }, "historyIgnore": "pass.*" }"#)

    #expect(decoded.hotkey == KeyCombination("cmd+space"))
    #expect(decoded.compact)
    #expect(decoded.reopenTimeout == 90)
    #expect(decoded.fileSearch.folders == ["~/Code"])
    #expect(decoded.fileSearch.exclusions == ["~/Library"])
    #expect(decoded.historyIgnore == "pass.*")
}

@Test func defaultsEncodePrettySortedAndDecodeBack() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(Config())
    let text = String(decoding: data, as: UTF8.self)

    #expect(try Config(json: data) == Config())
    #expect(text.contains(#""hotkey" : "ctrl+space""#))
    #expect(text.contains(#""historyIgnore" : null"#))
    #expect(text.firstRange(of: "compact")!.lowerBound < text.firstRange(of: "reopenTimeout")!.lowerBound)
}

@Test func problemsNameWhatIsWrong() {
    #expect(problem(#"{ "hotkey": "ctrl+spacebar" }"#)?.hasPrefix(#"hotkey: "ctrl+spacebar" isn't a key combination"#) == true)
    #expect(problem(#"{ "reopenTimeout": "soon" }"#)?.hasPrefix("reopenTimeout: ") == true)
    #expect(problem(#"{ "fileSearch": { "folders": "~" } }"#)?.hasPrefix("fileSearch.folders: ") == true)
    #expect(problem(#"{ "historyIgnore": "(unclosed" }"#)?.hasPrefix("historyIgnore: ") == true)
    #expect(problem(#"{ "compact" true }"#)?.contains("line 1") == true)
    #expect(problem("") != nil)
}
