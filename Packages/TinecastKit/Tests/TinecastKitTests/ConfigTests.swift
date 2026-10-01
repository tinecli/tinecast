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
    #expect(decoded.commands.isEmpty)
    #expect(decoded.aliases.isEmpty)
    #expect(decoded.hiddenItems.isEmpty)
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
    #expect(text.contains(#""commands" : ["#))
    #expect(text.contains(#""aliases" : {"#))
    #expect(text.contains(#""hiddenItems" : ["#))
}

private let deployID = "6F1C1E0A-8C1B-4F4C-9E43-2D2B7C1C0F11"

@Test func commandsDecodeWithDefaultsAndRoundTrip() throws {
    let decoded = try config(#"{ "commands": [{ "id": "\#(deployID)", "name": "Deploy", "command": "make deploy" }, { "id": "\#(UUID().uuidString)", "name": "Wipe", "command": "rm -rf ~/tmp/*", "symbol": "trash", "confirm": true }] }"#)

    #expect(decoded.commands.map(\.name) == ["Deploy", "Wipe"])
    #expect(decoded.commands[0].symbol == "terminal")
    #expect(!decoded.commands[0].confirm)
    #expect(decoded.commands[1].symbol == "trash")
    #expect(decoded.commands[1].confirm)
    #expect(try Config(json: JSONEncoder().encode(decoded)) == decoded)
}

@Test func commandBecomesAnItemWithAPrefixedID() {
    let item = Command(id: deployID, name: "Deploy", command: "make deploy").item

    #expect(item.id == "command:\(deployID)")
    #expect(item.title == "Deploy")
    #expect(item.icon == .symbol("terminal"))
    #expect(item.action == .run(Command(id: deployID, name: "Deploy", command: "make deploy")))
}

@Test func invalidCommandsNameTheProblem() {
    #expect(problem(#"{ "commands": [{ "id": "\#(deployID)", "name": " ", "command": "make" }] }"#)?.contains("A command needs a name.") == true)
    #expect(problem(#"{ "commands": [{ "id": "\#(deployID)", "name": "Deploy", "command": "" }] }"#)?.contains("\"Deploy\" needs a command to run.") == true)
    #expect(problem(#"{ "commands": [{ "id": "deploy", "name": "Deploy", "command": "make" }] }"#)?.contains("\"deploy\" isn't a UUID.") == true)
    #expect(problem(#"{ "commands": [{ "name": "Deploy", "command": "make" }] }"#)?.hasPrefix("commands.") == true)
}

@Test func duplicateCommandIDsAreRejected() {
    let duplicated = #"{ "commands": [{ "id": "\#(deployID)", "name": "Deploy", "command": "make" }, { "id": "\#(deployID)", "name": "Again", "command": "make" }] }"#

    #expect(problem(duplicated) == "commands: More than one command has the id \"\(deployID)\". Each command needs its own id.")
}

@Test func aliasesAndHiddenItemsDecode() throws {
    let decoded = try config(#"{ "aliases": { "system:lockScreen": "lk" }, "hiddenItems": ["/Applications/Chess.app"] }"#)

    #expect(decoded.aliases == ["system:lockScreen": "lk"])
    #expect(decoded.hiddenItems == ["/Applications/Chess.app"])
    #expect(problem(#"{ "aliases": ["lk"] }"#)?.hasPrefix("aliases: ") == true)
    #expect(problem(#"{ "hiddenItems": "Chess" }"#)?.hasPrefix("hiddenItems: ") == true)
}

@Test func problemsNameWhatIsWrong() {
    #expect(problem(#"{ "hotkey": "ctrl+spacebar" }"#)?.hasPrefix(#"hotkey: "ctrl+spacebar" isn't a key combination"#) == true)
    #expect(problem(#"{ "reopenTimeout": "soon" }"#)?.hasPrefix("reopenTimeout: ") == true)
    #expect(problem(#"{ "fileSearch": { "folders": "~" } }"#)?.hasPrefix("fileSearch.folders: ") == true)
    #expect(problem(#"{ "historyIgnore": "(unclosed" }"#)?.hasPrefix("historyIgnore: ") == true)
    #expect(problem(#"{ "compact" true }"#)?.contains("line 1") == true)
    #expect(problem("") != nil)
}

@Test func historyIgnoreMatchesWholeTrimmedQueriesOnly() throws {
    let ignoring = try config(#"{ "historyIgnore": "pass.*" }"#)

    #expect(ignoring.historyIgnores("password hunter2"))
    #expect(ignoring.historyIgnores(" passwd "))
    #expect(!ignoring.historyIgnores("my password"))
    #expect(!ignoring.historyIgnores("safari"))
    #expect(!Config().historyIgnores("password"))
}

@Test func invalidHistoryIgnoreIgnoresNothing() {
    var unchecked = Config()
    unchecked.historyIgnore = "(unclosed"

    #expect(!unchecked.historyIgnores("(unclosed"))
}
