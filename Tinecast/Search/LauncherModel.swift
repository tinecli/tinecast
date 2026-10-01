import Foundation
import Observation
import TinecastKit

struct ResultSection {
    let title: String
    let start: Int
}

@Observable
final class LauncherModel {
    private static let recentLimit = 5

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            search()
        }
    }
    var apps = AppCatalog() {
        didSet {
            appResults = rank(apps.alphabetical, query: query, frecency: frecency)
            updateResults()
        }
    }
    var config = Config() {
        didSet {
            if config.fileSearch != oldValue.fileSearch {
                filesProvider.fileSearch = config.fileSearch
                filesProvider.search(query)
            }
            updateResults()
        }
    }
    @ObservationIgnored var history = History()
    @ObservationIgnored var frecency = Frecency() {
        didSet {
            appResults = rank(apps.alphabetical, query: query, frecency: frecency)
            updateResults()
        }
    }
    private(set) var isPresented = false
    private(set) var results: [Item] = []
    private(set) var sections: [ResultSection] = []
    private(set) var selectedIndex = 0
    @ObservationIgnored private var appResults: [Item] = []
    @ObservationIgnored private var fileResults: [Item] = []
    @ObservationIgnored private var navigator = HistoryNavigator()
    @ObservationIgnored private var closedAt: Date?
    private var isSearchingFiles = false
    @ObservationIgnored private lazy var filesProvider = FilesProvider { [weak self] items in
        guard let self else { return }
        isSearchingFiles = false
        guard items != fileResults else { return }
        fileResults = items
        updateResults()
    }

    var selectedItem: Item? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    var showsNoResults: Bool {
        results.isEmpty && !isSearchingFiles && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func edit(_ text: String) {
        guard text != query else { return }
        navigator.reset()
        query = text
    }

    func moveUp() {
        guard navigator.isActive || selectedIndex == 0 else {
            selectedIndex -= 1
            return
        }
        guard let recalled = navigator.older(typed: query, in: history) else { return }
        query = recalled
    }

    func moveDown() {
        guard navigator.isActive else {
            selectedIndex = min(selectedIndex + 1, max(results.count - 1, 0))
            return
        }
        guard let recalled = navigator.newer(in: history) else { return }
        query = recalled
    }

    func record(_ item: Item) {
        guard !config.historyIgnores(query) else { return }
        history.record(query)
        frecency.record(query: query, itemID: item.id, at: .now)
    }

    func present() {
        if let closedAt, Date.now.timeIntervalSince(closedAt) > config.reopenTimeout {
            query = ""
        }
        navigator.reset()
        isPresented = true
    }

    func dismiss() {
        isPresented = false
        closedAt = .now
    }

    private func search() {
        appResults = rank(apps.alphabetical, query: query, frecency: frecency)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        fileResults = fileResults.filter { $0.title.localizedStandardContains(trimmed) }
        isSearchingFiles = true
        filesProvider.search(query)
        layOut(currentGroups)
        selectedIndex = 0
    }

    private var recents: [Item] {
        apps.recents(learned: frecency.suggestions(limit: Self.recentLimit, now: .now), limit: Self.recentLimit) { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(filePath: path)
            let folder = ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
            return Item(id: path, title: FileManager.default.displayName(atPath: path), subtitle: folder, icon: .file(url), action: .open(url))
        }
    }

    private var currentGroups: [(title: String, items: [Item])] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [("Applications", appResults), ("Files", fileResults)]
        }
        return config.compact ? [] : [("Recent", recents), ("Applications", apps.alphabetical)]
    }

    private func layOut(_ groups: [(title: String, items: [Item])]) {
        let shown = groups.filter { !$0.items.isEmpty }
        results = shown.flatMap(\.items)
        sections = shown.indices.map { index in
            ResultSection(title: shown[index].title, start: shown[..<index].reduce(0) { $0 + $1.items.count })
        }
    }

    private func updateResults() {
        let selectedID = selectedItem?.id
        layOut(currentGroups)
        guard selectedItem?.id != selectedID else { return }
        selectedIndex = results.firstIndex { $0.id == selectedID } ?? min(selectedIndex, max(results.count - 1, 0))
    }
}
