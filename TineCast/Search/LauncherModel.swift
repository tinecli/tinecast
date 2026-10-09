import Foundation
import Observation
import TineCastKit

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
            searchable = (apps.alphabetical + config.commands.map(\.item) + SystemAction.allCases.map(\.item)).filter { !config.hiddenItems.contains($0.id) }
        }
    }
    var config = Config() {
        didSet {
            if config.fileSearch != oldValue.fileSearch {
                filesProvider.fileSearch = config.fileSearch
                filesProvider.search(query)
            }
            if config.calculator != oldValue.calculator {
                calculation = calculate(query, rates: exchangeRates, localCurrency: Locale.current.currency?.identifier, locale: .current, settings: config.calculator)
            }
            searchable = (apps.alphabetical + config.commands.map(\.item) + SystemAction.allCases.map(\.item)).filter { !config.hiddenItems.contains($0.id) }
        }
    }
    var exchangeRates: ExchangeRates? {
        didSet {
            calculation = calculate(query, rates: exchangeRates, localCurrency: Locale.current.currency?.identifier, locale: .current, settings: config.calculator)
            updateResults()
        }
    }
    @ObservationIgnored var refreshRates: () -> Void = {}
    @ObservationIgnored var history = History()
    @ObservationIgnored var frecency = Frecency() {
        didSet {
            rankedResults = rank(searchable, query: query, frecency: frecency, aliases: config.aliases)
            updateResults()
        }
    }
    private(set) var isPresented = false
    private(set) var results: [Item] = []
    private(set) var sections: [ResultSection] = []
    private(set) var selectedIndex = 0
    private(set) var calculation: Calculation?
    @ObservationIgnored private var searchable: [Item] = [] {
        didSet {
            rankedResults = rank(searchable, query: query, frecency: frecency, aliases: config.aliases)
            updateResults()
        }
    }
    @ObservationIgnored private var rankedResults: [Item] = []
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
        if case .copy = item.action { return }
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
        calculation = calculate(query, rates: exchangeRates, localCurrency: Locale.current.currency?.identifier, locale: .current, settings: config.calculator)
        if calculation != nil || exchangeRates == nil { refreshRates() }
        rankedResults = rank(searchable, query: query, frecency: frecency, aliases: config.aliases)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        fileResults = fileResults.filter { $0.title.localizedStandardContains(trimmed) }
        isSearchingFiles = true
        filesProvider.search(query)
        layOut(currentGroups)
        selectedIndex = 0
    }

    private var calculatorResults: [Item] {
        guard let calculation else { return [] }
        return [Item(id: "calculator", title: calculation.result.text, subtitle: calculation.expression, icon: .symbol("equal.circle"), action: .copy(calculation.raw, decimal: calculation.decimal))]
    }

    private var recents: [Item] {
        apps.recents(learned: frecency.suggestions(limit: Self.recentLimit, now: .now), limit: Self.recentLimit, excluding: Set(config.hiddenItems)) { [searchable] path in
            if let item = searchable.first(where: { $0.id == path }) { return item }
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(filePath: path)
            let folder = ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
            return Item(id: path, title: FileManager.default.displayName(atPath: path), subtitle: folder, icon: .file(url), action: .open(url))
        }
    }

    private var currentGroups: [(title: String, items: [Item])] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [("Calculator", calculatorResults), ("Results", rankedResults), ("Files", fileResults.filter { !config.hiddenItems.contains($0.id) })]
        }
        return config.compact ? [] : [("Recent", recents), ("Applications", apps.alphabetical.filter { !config.hiddenItems.contains($0.id) })]
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
