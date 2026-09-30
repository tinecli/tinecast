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

    private enum CodingKeys: String, CodingKey {
        case hotkey, launchAtLogin, compact, reopenTimeout, fileSearch, historyIgnore
    }

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Config()
        hotkey = try container.decodeIfPresent(KeyCombination.self, forKey: .hotkey) ?? defaults.hotkey
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        compact = try container.decodeIfPresent(Bool.self, forKey: .compact) ?? defaults.compact
        reopenTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .reopenTimeout) ?? defaults.reopenTimeout
        fileSearch = try container.decodeIfPresent(FileSearch.self, forKey: .fileSearch) ?? defaults.fileSearch
        historyIgnore = try container.decodeIfPresent(String.self, forKey: .historyIgnore)
        if let historyIgnore, (try? Regex(historyIgnore)) == nil {
            throw DecodingError.dataCorruptedError(forKey: .historyIgnore, in: container, debugDescription: "\"\(historyIgnore)\" isn't a valid regular expression.")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(compact, forKey: .compact)
        try container.encode(reopenTimeout, forKey: .reopenTimeout)
        try container.encode(fileSearch, forKey: .fileSearch)
        try container.encode(historyIgnore, forKey: .historyIgnore)
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
