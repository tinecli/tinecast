import Foundation
import TineCastKit

final class FilesProvider: NSObject {
    private static let minimumQueryLength = 3
    private static let maximumResults = 5

    var fileSearch = Config.FileSearch()
    private var query: NSMetadataQuery?
    private var pendingSearch: Task<Void, Never>?
    private let onUpdate: ([Item]) -> Void

    init(onUpdate: @escaping ([Item]) -> Void) {
        self.onUpdate = onUpdate
    }

    func search(_ text: String) {
        pendingSearch?.cancel()
        if let query {
            query.stop()
            NotificationCenter.default.removeObserver(self, name: nil, object: query)
            self.query = nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumQueryLength else {
            onUpdate([])
            return
        }
        pendingSearch = Task { [weak self] in
            guard (try? await Task.sleep(for: .milliseconds(100))) != nil, let self else { return }
            start(trimmed)
        }
    }

    private func start(_ trimmed: String) {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "%K CONTAINS[cd] %@ AND %K != %@",
            NSMetadataItemDisplayNameKey, trimmed,
            NSMetadataItemContentTypeKey, "com.apple.application-bundle"
        )
        query.searchScopes = fileSearch.folders.map { NSString(string: $0).standardizingPath }
        query.valueListAttributes = [NSMetadataItemPathKey, NSMetadataItemDisplayNameKey]
        query.sortDescriptors = [
            NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: false),
            NSSortDescriptor(key: NSMetadataItemDisplayNameKey, ascending: true),
        ]
        NotificationCenter.default.addObserver(self, selector: #selector(publish), name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(publish), name: .NSMetadataQueryDidUpdate, object: query)
        self.query = query
        query.start()
    }

    @objc private func publish() {
        guard let query else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        let exclusions = fileSearch.exclusions.map { NSString(string: $0).standardizingPath }
        let items = (0..<query.resultCount).lazy.compactMap { index -> Item? in
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String,
                  !exclusions.contains(where: { path == $0 || path.hasPrefix($0 + "/") })
            else { return nil }
            let url = URL(filePath: path)
            let folder = ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
            return Item(id: path, title: name, subtitle: folder, icon: .file(url), action: .open(url))
        }
        onUpdate(Array(items.prefix(Self.maximumResults)))
    }
}
