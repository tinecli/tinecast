import Foundation

public struct History: Codable, Sendable, Equatable {
    public static let capacity = 500

    public private(set) var entries: [String] = []
    public var ignorePattern: String?

    private enum CodingKeys: String, CodingKey {
        case entries
    }

    public init(ignorePattern: String? = nil) {
        self.ignorePattern = ignorePattern
    }

    public mutating func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, entries.last != trimmed else { return }
        if let ignorePattern, let regex = try? Regex(ignorePattern), trimmed.wholeMatch(of: regex) != nil { return }
        entries.append(trimmed)
        entries.removeFirst(max(0, entries.count - Self.capacity))
    }
}
