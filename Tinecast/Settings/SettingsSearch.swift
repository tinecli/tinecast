import TinecastKit

struct SearchResult: Identifiable, Hashable {
    let pane: Pane
    let title: String
    var icon: Icon?
    var anchor: String?
    var filter: String?

    var id: String { "\(pane.rawValue)/\(anchor ?? "all")" }
}

struct SearchSection: Identifiable {
    let pane: Pane
    let results: [SearchResult]

    var id: Pane { pane }
}

extension SettingsModel {
    private static let applicationLimit = 8

    func searchSections(matching query: String) -> [SearchSection] {
        guard !query.isEmpty else { return [] }
        let aliases = config.aliases
        let settings = SettingRow.allCases.compactMap { row in
            matchScore(query: query, title: row.label, keywords: row.keywords).map {
                (result: SearchResult(pane: row.pane, title: row.label, anchor: row.rawValue), score: $0)
            }
        }
        let items = [
            (pane: Pane.applications, items: applications, filtersByTitle: true),
            (pane: .systemActions, items: SystemAction.allCases.map(\.item), filtersByTitle: true),
            (pane: .commands, items: commandItems, filtersByTitle: false),
        ].flatMap { source in
            source.items.compactMap { item in
                matchScore(query: query, title: item.title, keywords: item.keywords, alias: aliases[item.id]).map {
                    (result: SearchResult(pane: source.pane, title: item.title, icon: item.icon, anchor: item.id, filter: source.filtersByTitle ? item.title : nil), score: $0)
                }
            }
        }
        let scored = (settings + items).sorted { $0.score > $1.score }
        let panes = Pane.sidebarGroups.flatMap(\.panes)
        let sections = panes.compactMap { pane -> (section: SearchSection, score: Double)? in
            let hits = scored.filter { $0.result.pane == pane }
            guard let best = hits.first?.score else { return nil }
            let shown = hits.prefix(pane == .applications ? Self.applicationLimit : hits.count).map(\.result)
            let showAll = SearchResult(pane: pane, title: "Show All in Applications", filter: query)
            return (SearchSection(pane: pane, results: shown + (hits.count > shown.count ? [showAll] : [])), best)
        }
        return sections.sorted { $0.score > $1.score }.map(\.section)
    }
}
