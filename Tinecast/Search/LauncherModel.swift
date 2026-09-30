import Observation
import TinecastKit

@Observable
final class LauncherModel {
    var query = "" {
        didSet { updateResults() }
    }
    var items: [Item] = [] {
        didSet { updateResults() }
    }
    var isPresented = false
    private(set) var results: [Item] = []
    private(set) var selectedIndex = 0

    var selectedItem: Item? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
    }

    private func updateResults() {
        results = rank(items, query: query)
        selectedIndex = 0
    }
}
