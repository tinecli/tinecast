import Foundation
import TinecastKit

final class AppsProvider: NSObject {
    private let query = NSMetadataQuery()
    private let onUpdate: ([Item]) -> Void

    init(onUpdate: @escaping ([Item]) -> Void) {
        self.onUpdate = onUpdate
        super.init()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemContentTypeKey, "com.apple.application-bundle")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemDisplayNameKey, ascending: true)]
        NotificationCenter.default.addObserver(self, selector: #selector(publish), name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(publish), name: .NSMetadataQueryDidUpdate, object: query)
        query.start()
    }

    @objc private func publish() {
        query.disableUpdates()
        defer { query.enableUpdates() }
        let items = query.results.compactMap { result -> Item? in
            guard let item = result as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
            else { return nil }
            let url = URL(filePath: path)
            let title = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
            return Item(id: path, title: title, icon: .file(url), action: .open(url))
        }
        onUpdate(items)
    }
}
