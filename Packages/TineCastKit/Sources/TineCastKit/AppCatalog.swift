import Foundation

public struct AppCatalog: Sendable {
    public let alphabetical: [Item]
    private let byLastUse: [Item]
    private let byID: [String: Item]

    public init(_ apps: [(item: Item, lastUsed: Date?)] = []) {
        alphabetical = apps.map(\.item).sorted { lhs, rhs in
            let order = lhs.title.localizedStandardCompare(rhs.title)
            return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
        }
        byLastUse = apps
            .compactMap { app in app.lastUsed.map { (item: app.item, lastUsed: $0) } }
            .sorted { $0.lastUsed > $1.lastUsed }
            .map(\.item)
        byID = Dictionary(apps.map { ($0.item.id, $0.item) }, uniquingKeysWith: { first, _ in first })
    }

    public func recents(learned ids: [String], limit: Int, excluding hidden: Set<String> = [], resolve: (String) -> Item?) -> [Item] {
        let learned = ids.filter { !hidden.contains($0) }.compactMap { byID[$0] ?? resolve($0) }
        let shownIDs = hidden.union(learned.map(\.id))
        return Array((learned + byLastUse.filter { !shownIDs.contains($0.id) }).prefix(limit))
    }
}
