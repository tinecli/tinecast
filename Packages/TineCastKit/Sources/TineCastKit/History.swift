import Foundation

public struct History: Codable, Sendable, Equatable {
    public static let capacity = 500

    public private(set) var entries: [String] = []

    public init() {}

    public mutating func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, entries.last != trimmed else { return }
        entries.append(trimmed)
        entries.removeFirst(max(0, entries.count - Self.capacity))
    }
}
