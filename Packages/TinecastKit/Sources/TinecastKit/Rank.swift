import Foundation

public func rank(_ items: [Item], query: String, frecency: Frecency = Frecency(), now: Date = .now) -> [Item] {
    items
        .compactMap { item -> (item: Item, score: Double)? in
            guard let match = matchScore(query: query, title: item.title, keywords: item.keywords) else { return nil }
            let learned = frecency.score(query: query, itemID: item.id, now: now)
            return (item, match + 0.25 * learned / (learned + 2))
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            let order = lhs.item.title.localizedStandardCompare(rhs.item.title)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.item.id < rhs.item.id
        }
        .map(\.item)
}
