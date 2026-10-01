import Foundation

public struct Config: Codable, Equatable, Sendable {
    public struct FileSearch: Codable, Equatable, Sendable {
        public var folders = ["~"]
        public var exclusions = ["~/Library"]

        public init() {}

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let defaults = FileSearch()
            folders = try container.decodeIfPresent([String].self, forKey: .folders) ?? defaults.folders
            exclusions = try container.decodeIfPresent([String].self, forKey: .exclusions) ?? defaults.exclusions
        }
    }

    public var hotkey = KeyCombination("ctrl+space")!
    public var launchAtLogin = false
    public var compact = false
    public var reopenTimeout: TimeInterval = 90
    public var fileSearch = FileSearch()
    public var historyIgnore: String?
    public var commands: [Command] = []
    public var aliases: [String: String] = [:]
    public var hiddenItems: [String] = []

    private enum CodingKeys: String, CodingKey {
        case hotkey, launchAtLogin, compact, reopenTimeout, fileSearch, historyIgnore, commands, aliases, hiddenItems
    }

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Config()
        hotkey = try container.decodeIfPresent(KeyCombination.self, forKey: .hotkey) ?? defaults.hotkey
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        compact = try container.decodeIfPresent(Bool.self, forKey: .compact) ?? defaults.compact
        if (try? container.decodeIfPresent(String.self, forKey: .reopenTimeout)) == "never" {
            reopenTimeout = .infinity
        } else {
            reopenTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .reopenTimeout) ?? defaults.reopenTimeout
        }
        fileSearch = try container.decodeIfPresent(FileSearch.self, forKey: .fileSearch) ?? defaults.fileSearch
        historyIgnore = try container.decodeIfPresent(String.self, forKey: .historyIgnore)
        if let historyIgnoreProblem {
            throw DecodingError.dataCorruptedError(forKey: .historyIgnore, in: container, debugDescription: historyIgnoreProblem)
        }
        commands = try container.decodeIfPresent([Command].self, forKey: .commands) ?? defaults.commands
        let ids = commands.map(\.id)
        if let duplicate = ids.enumerated().first(where: { ids[..<$0.offset].contains($0.element) })?.element {
            throw DecodingError.dataCorruptedError(forKey: .commands, in: container, debugDescription: "More than one command has the id \"\(duplicate)\". Each command needs its own id.")
        }
        aliases = try container.decodeIfPresent([String: String].self, forKey: .aliases) ?? defaults.aliases
        hiddenItems = try container.decodeIfPresent([String].self, forKey: .hiddenItems) ?? defaults.hiddenItems
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(compact, forKey: .compact)
        if reopenTimeout.isInfinite {
            try container.encode("never", forKey: .reopenTimeout)
        } else {
            try container.encode(reopenTimeout, forKey: .reopenTimeout)
        }
        try container.encode(fileSearch, forKey: .fileSearch)
        try container.encode(historyIgnore, forKey: .historyIgnore)
        try container.encode(commands, forKey: .commands)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(hiddenItems, forKey: .hiddenItems)
    }

    public var historyIgnoreProblem: String? {
        guard let historyIgnore, (try? Regex(historyIgnore)) == nil else { return nil }
        return "\"\(historyIgnore)\" isn't a valid regular expression."
    }

    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public func keepingValidValues(from saved: Config) -> Config {
        var valid = self
        valid.commands = commands.compactMap { command in
            command.problem == nil ? command : saved.commands.first { $0.id == command.id }
        }
        if historyIgnoreProblem != nil { valid.historyIgnore = saved.historyIgnore }
        return valid
    }

    public mutating func setAlias(_ alias: String, for id: String) {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        aliases[id] = trimmed.isEmpty ? nil : trimmed
    }

    public mutating func setHidden(_ hidden: Bool, for id: String) {
        hiddenItems.removeAll { $0 == id }
        if hidden { hiddenItems.append(id) }
    }

    public func historyIgnores(_ query: String) -> Bool {
        guard let historyIgnore, let regex = try? Regex(historyIgnore) else { return false }
        return query.trimmingCharacters(in: .whitespacesAndNewlines).wholeMatch(of: regex) != nil
    }

    public init(json data: Data) throws(ConfigError) {
        do {
            self = try JSONDecoder().decode(Config.self, from: data)
        } catch let error as DecodingError {
            throw ConfigError(decoding: error)
        } catch {
            throw ConfigError(errorDescription: error.localizedDescription)
        }
    }
}

public struct ConfigError: LocalizedError, Equatable {
    public let errorDescription: String?

    init(errorDescription: String) {
        self.errorDescription = errorDescription
    }

    init(decoding error: DecodingError) {
        let context: DecodingError.Context? = switch error {
        case .dataCorrupted(let context), .typeMismatch(_, let context), .valueNotFound(_, let context), .keyNotFound(_, let context): context
        @unknown default: nil
        }
        guard let context else {
            errorDescription = error.localizedDescription
            return
        }
        let detail = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String ?? context.debugDescription
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        errorDescription = path.isEmpty ? detail : "\(path): \(detail)"
    }
}
