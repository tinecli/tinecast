import Foundation
import Testing
import TineCastKit

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

@Test func neverReopenTimeoutRoundTripsAsAString() throws {
    var never = Config()
    never.reopenTimeout = .infinity
    let text = String(decoding: try never.json(), as: UTF8.self)

    #expect(text.contains(#""reopenTimeout" : "never""#))
    #expect(try Config(json: never.json()).reopenTimeout == .infinity)
    #expect(try config(#"{ "reopenTimeout": 0 }"#).reopenTimeout == 0)
    #expect(problem(#"{ "reopenTimeout": "always" }"#)?.hasPrefix("reopenTimeout: ") == true)
}

@Test func jsonMatchesThePrettySortedDefaultWrite() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    #expect(try Config().json() == encoder.encode(Config()))
}

@Test func keepingValidValuesFallsBackToTheSavedVersion() {
    let saved = Command(id: deployID, name: "Deploy", command: "make deploy")
    var lastSaved = Config()
    lastSaved.commands = [saved]
    lastSaved.historyIgnore = "pass.*"
    var draft = lastSaved
    draft.commands = [Command(id: deployID, name: " ", command: "make deploy"), Command(name: "New", command: ""), Command(name: "Ok", command: "ls")]
    draft.historyIgnore = "(unclosed"
    draft.compact = true

    let valid = draft.keepingValidValues(from: lastSaved)

    #expect(valid.commands.map(\.name) == ["Deploy", "Ok"])
    #expect(valid.historyIgnore == "pass.*")
    #expect(valid.compact)
}

@Test func aliasAndHiddenEditsTrimAndRemove() {
    var edited = Config()
    edited.setAlias("  lk ", for: "system:lockScreen")
    edited.setHidden(true, for: "/Applications/Chess.app")
    edited.setHidden(true, for: "/Applications/Chess.app")

    #expect(edited.aliases == ["system:lockScreen": "lk"])
    #expect(edited.hiddenItems == ["/Applications/Chess.app"])

    edited.setAlias(" ", for: "system:lockScreen")
    edited.setHidden(false, for: "/Applications/Chess.app")

    #expect(edited.aliases.isEmpty)
    #expect(edited.hiddenItems.isEmpty)
}

@Test func calculatorSettingsRoundTrip() throws {
    let decoded = try config(#"{ "calculator": { "autoConvertUnits": false, "inchFraction": 32, "precision": 4 } }"#)

    #expect(decoded.calculator.autoConvertUnits == false)
    #expect(decoded.calculator.inchFraction == 32)
    #expect(decoded.calculator.precision == .places(4))
    #expect(try config(#"{ "calculator": { "precision": "full" } }"#).calculator.precision == .full)
    #expect(try config(#"{ "calculator": {} }"#).calculator == Config.Calculator())
    #expect(try Config(json: decoded.json()) == decoded)
}

@Test func invalidCalculatorSettingsAreExplained() {
    #expect(problem(#"{ "calculator": { "inchFraction": 10 } }"#) == "calculator.inchFraction: Use one of 2, 4, 8, 16, 32, 64.")
    #expect(problem(#"{ "calculator": { "precision": 20 } }"#) == "calculator.precision: Decimal places must be from 0 to 15.")
    #expect(problem(#"{ "calculator": { "precision": "lots" } }"#) == "calculator.precision: Use \"automatic\", \"full\" or a number of decimal places.")
}
