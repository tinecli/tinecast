import Foundation

public struct Command: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var command: String
    public var symbol: String
    public var confirm: Bool
    public var useShell: Bool

    public init(id: String = UUID().uuidString, name: String, command: String, symbol: String = "terminal", confirm: Bool = false, useShell: Bool = false) {
        self.id = id
        self.name = name
        self.command = command
        self.symbol = symbol
        self.confirm = confirm
        self.useShell = useShell
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        command = try container.decode(String.self, forKey: .command)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? "terminal"
        confirm = try container.decodeIfPresent(Bool.self, forKey: .confirm) ?? false
        useShell = try container.decodeIfPresent(Bool.self, forKey: .useShell) ?? false
        guard UUID(uuidString: id) != nil else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "\"\(id)\" isn't a UUID. Run uuidgen in Terminal to make one.")
        }
        if let nameProblem {
            throw DecodingError.dataCorruptedError(forKey: .name, in: container, debugDescription: nameProblem)
        }
        if let commandProblem {
            throw DecodingError.dataCorruptedError(forKey: .command, in: container, debugDescription: commandProblem)
        }
    }

    public var nameProblem: String? {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A command needs a name." : nil
    }

    public var commandProblem: String? {
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nameProblem == nil ? "\"\(name)\" needs a command to run." : "Enter a command to run."
        }
        guard !useShell else { return nil }
        do {
            _ = try splitWords(command)
            return nil
        } catch {
            return error.errorDescription
        }
    }

    public var problem: String? {
        nameProblem ?? commandProblem
    }

    public var item: Item {
        Item(id: "command:\(id)", title: name, icon: .symbol(symbol), action: .run(self))
    }

    public func invocation(isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) throws(InvocationError) -> Invocation {
        guard !useShell else { return Invocation(executable: "/bin/zsh", arguments: ["-l", "-c", command]) }
        let words = try splitWords(command)
        guard let first = words.first else { throw InvocationError("Enter a command to run.") }
        let name = first.hasPrefix("~/") ? URL.homeDirectory.appending(path: String(first.dropFirst(2))).path(percentEncoded: false) : first
        if name.hasPrefix("/") {
            guard isExecutable(name) else { throw InvocationError("\"\(name)\" isn't an executable file.") }
            return Invocation(executable: name, arguments: Array(words.dropFirst()))
        }
        guard !name.contains("/") else { throw InvocationError("\"\(name)\" isn't a full path. Start it with / or ~/.") }
        guard let executable = Invocation.searchPath.map({ "\($0)/\(name)" }).first(where: isExecutable) else {
            throw InvocationError("\"\(name)\" wasn't found in \(Invocation.searchPath.joined(separator: ", ")). Use its full path or turn on Run in Login Shell.")
        }
        return Invocation(executable: executable, arguments: Array(words.dropFirst()))
    }
}

public struct Invocation: Equatable, Sendable {
    public static let searchPath = ["/usr/bin", "/bin", "/usr/sbin", "/sbin", "/opt/homebrew/bin", "/usr/local/bin"]

    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public struct InvocationError: LocalizedError, Equatable {
    public let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

public func splitWords(_ text: String) throws(InvocationError) -> [String] {
    var words: [String] = []
    var word: String?
    var quote: Character?
    var characters = text.makeIterator()
    while let character = characters.next() {
        if quote == "'" {
            if character == "'" { quote = nil } else { word = (word ?? "") + String(character) }
            continue
        }
        if character == "\\" {
            guard let escaped = characters.next() else { throw InvocationError("The command ends with a backslash.") }
            let keepsBackslash = quote == "\"" && !"\"\\$`\n".contains(escaped)
            if escaped != "\n" { word = (word ?? "") + (keepsBackslash ? "\\" : "") + String(escaped) }
            continue
        }
        if quote == "\"" {
            if character == "\"" { quote = nil } else { word = (word ?? "") + String(character) }
            continue
        }
        if character == "'" || character == "\"" {
            quote = character
            word = word ?? ""
            continue
        }
        if character.isWhitespace {
            if let word { words.append(word) }
            word = nil
            continue
        }
        word = (word ?? "") + String(character)
    }
    guard quote == nil else { throw InvocationError("The command has an unclosed quote.") }
    if let word { words.append(word) }
    return words
}
