import Foundation
import Observation
import TinecastKit

@Observable
final class LauncherModel {
    private static let suggestionLimit = 8

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            search()
        }
    }
    var items: [Item] = [] {
        didSet {
            appResults = rank(items, query: query, frecency: frecency)
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
            appResults = rank(items, query: query, frecency: frecency)
            updateResults()
        }
    }
    private(set) var isPresented = false
    private(set) var results: [Item] = []
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
        appResults = rank(items, query: query, frecency: frecency)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        fileResults = fileResults.filter { $0.title.localizedStandardContains(trimmed) }
        isSearchingFiles = true
        filesProvider.search(query)
        results = currentResults
        selectedIndex = 0
    }

    private var suggestions: [Item] {
        let apps = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return frecency.suggestions(limit: Self.suggestionLimit, now: .now).compactMap { id in
            if let app = apps[id] { return app }
            guard FileManager.default.fileExists(atPath: id) else { return nil }
            let url = URL(filePath: id)
            let folder = ((id as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
            return Item(id: id, title: FileManager.default.displayName(atPath: id), subtitle: folder, icon: .file(url), action: .open(url))
        }
    }

    private var currentResults: [Item] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return appResults + fileResults }
        return config.compact ? [] : suggestions
    }

    private func updateResults() {
        let selectedID = selectedItem?.id
        results = currentResults
        selectedIndex = results.firstIndex { $0.id == selectedID } ?? min(selectedIndex, max(results.count - 1, 0))
    }
}
