import Foundation

public struct Frecency: Codable, Sendable, Equatable {
    public static let halfLife: TimeInterval = 7 * 24 * 60 * 60
    public static let capacity = 1000

    private struct Record: Codable, Sendable, Equatable {
        let query: String
        let itemID: String
        var weight: Double
        var lastUsed: Date

        func weight(at now: Date) -> Double {
            weight * pow(0.5, max(0, now.timeIntervalSince(lastUsed)) / Frecency.halfLife)
        }
    }

    private var records: [Record] = []

    public init() {}

    public mutating func record(query: String, itemID: String, at date: Date) {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        if let index = records.firstIndex(where: { $0.query == normalized && $0.itemID == itemID }) {
            records[index].weight = records[index].weight(at: date) + 1
            records[index].lastUsed = date
            return
        }
        records.append(Record(query: normalized, itemID: itemID, weight: 1, lastUsed: date))
        guard records.count > Self.capacity,
              let weakest = records.indices.dropLast().min(by: { records[$0].weight(at: date) < records[$1].weight(at: date) })
        else { return }
        records.remove(at: weakest)
    }

    public func score(query: String, itemID: String, now: Date) -> Double {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return records
            .filter { $0.itemID == itemID && $0.query.hasPrefix(normalized) }
            .reduce(0) { $0 + $1.weight(at: now) }
    }

    public func suggestions(limit: Int, now: Date) -> [String] {
        let totals: [String: Double] = Dictionary(records.map { ($0.itemID, $0.weight(at: now)) }, uniquingKeysWith: +)
        return totals
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map(\.key)
    }
}
