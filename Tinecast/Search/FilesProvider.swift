import Foundation
import TinecastKit

final class FilesProvider: NSObject {
    private static let minimumQueryLength = 3
    private static let maximumResults = 5

    private var query: NSMetadataQuery?
    private let onUpdate: ([Item]) -> Void
    private let libraryPrefix = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library", directoryHint: .isDirectory).path(percentEncoded: false)

    init(onUpdate: @escaping ([Item]) -> Void) {
        self.onUpdate = onUpdate
    }

    func search(_ text: String) {
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

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "%K CONTAINS[cd] %@ AND %K != %@",
            NSMetadataItemDisplayNameKey, trimmed,
            NSMetadataItemContentTypeKey, "com.apple.application-bundle"
        )
        query.searchScopes = [NSMetadataQueryUserHomeScope]
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
        let items = (0..<query.resultCount).lazy.compactMap { index -> Item? in
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String,
                  !path.hasPrefix(self.libraryPrefix)
            else { return nil }
            let url = URL(filePath: path)
            let folder = ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
            return Item(id: path, title: name, subtitle: folder, icon: .file(url), action: .open(url))
        }
        onUpdate(Array(items.prefix(Self.maximumResults)))
    }
}
