import Foundation

public func rank(_ items: [Item], query: String) -> [Item] {
    guard !query.isEmpty else { return [] }
    return items.filter { $0.title.localizedStandardContains(query) }
}
