import Observation
import TinecastKit

@Observable
final class LauncherModel {
    var query = "" {
        didSet {
            appResults = rank(items, query: query)
            filesProvider.search(query)
            selectedIndex = 0
        }
    }
    var items: [Item] = [] {
        didSet { appResults = rank(items, query: query) }
    }
    var isPresented = false
    private(set) var results: [Item] = []
    private(set) var selectedIndex = 0
    private var appResults: [Item] = [] {
        didSet { updateResults() }
    }
    private var fileResults: [Item] = [] {
        didSet { updateResults() }
    }
    @ObservationIgnored private lazy var filesProvider = FilesProvider { [weak self] items in self?.fileResults = items }

    var selectedItem: Item? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
    }

    private func updateResults() {
        let selectedID = selectedItem?.id
        results = appResults + fileResults
        selectedIndex = results.firstIndex { $0.id == selectedID } ?? min(selectedIndex, max(results.count - 1, 0))
    }
}
