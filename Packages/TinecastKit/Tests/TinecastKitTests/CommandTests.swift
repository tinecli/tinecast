import Foundation
import Testing
import TinecastKit

private let installed: Set = ["/usr/bin/shortcuts", "/opt/homebrew/bin/rg", "/usr/local/bin/rg", "/Users/me/bin/tool"]

private func invocation(_ text: String, useShell: Bool = false) throws -> Invocation {
    try Command(name: "Test", command: text, useShell: useShell).invocation { installed.contains($0) }
}

@Test func splitsWordsWithPOSIXQuoting() throws {
    #expect(try splitWords(#"shortcuts run "txt file""#) == ["shortcuts", "run", "txt file"])
    #expect(try splitWords(#"echo 'a "b" $HOME' "c \"d\" \x" e\ f"#) == ["echo", #"a "b" $HOME"#, #"c "d" \x"#, "e f"])
    #expect(try splitWords("  ls   -la\t~/x  ") == ["ls", "-la", "~/x"])
    #expect(try splitWords(#"say "" ''"#) == ["say", "", ""])
    #expect(try splitWords("a\\\nb") == ["ab"])
    #expect(try splitWords("ls | wc *") == ["ls", "|", "wc", "*"])
}

@Test func unbalancedQuotingIsAProblem() {
    #expect(throws: InvocationError.self) { try splitWords(#"echo "open"#) }
    #expect(throws: InvocationError.self) { try splitWords("echo 'open") }
    #expect(throws: InvocationError.self) { try splitWords("echo \\") }
    #expect(Command(name: "Bad", command: "echo 'open").problem == "The command has an unclosed quote.")
    #expect(Command(name: "Shell", command: "echo 'open", useShell: true).problem == nil)
}

@Test func resolvesExecutablesAgainstTheFixedSearchPath() throws {
    #expect(try invocation(#"shortcuts run "txt file""#) == Invocation(executable: "/usr/bin/shortcuts", arguments: ["run", "txt file"]))
    #expect(try invocation("rg TODO").executable == "/opt/homebrew/bin/rg")
    #expect(try invocation("/Users/me/bin/tool --flag").arguments == ["--flag"])
}

@Test func expandsOnlyALeadingTildeInTheExecutable() throws {
    let tool = URL.homeDirectory.appending(path: "bin/tool").path(percentEncoded: false)
    let resolved = try Command(name: "Tool", command: "~/bin/tool ~/x").invocation { $0 == tool }

    #expect(resolved == Invocation(executable: tool, arguments: ["~/x"]))
}

@Test func unresolvableExecutablesNameTheProblem() {
    #expect(throws: InvocationError.self) { try invocation("nope") }
    #expect(throws: InvocationError.self) { try invocation("/usr/bin/nope") }
    #expect(throws: InvocationError.self) { try invocation("./script.sh") }
    #expect((try? invocation("nope")) == nil)
}

@Test func loginShellRunsTheTextThroughZsh() throws {
    #expect(try invocation("ls | wc -l", useShell: true) == Invocation(executable: "/bin/zsh", arguments: ["-l", "-c", "ls | wc -l"]))
}

@Test func useShellDefaultsToFalseAndRoundTrips() throws {
    let id = UUID().uuidString
    let decoded = try Config(json: Data(#"{ "commands": [{ "id": "\#(id)", "name": "A", "command": "ls" }, { "id": "\#(UUID().uuidString)", "name": "B", "command": "ls", "useShell": true }] }"#.utf8))

    #expect(decoded.commands.map(\.useShell) == [false, true])
    #expect(try Config(json: decoded.json()) == decoded)
}
