import Foundation
import TinecastKit

final class AppsProvider: NSObject {
    private static let folders = ["/Applications", "/System/Applications", URL.homeDirectory.appending(path: "Applications").path(percentEncoded: false), "/System/Library/CoreServices/Applications"]
    private static let preferredFolders = ["/Applications/", "/System/Applications/"]
    private static let finderPath = "/System/Library/CoreServices/Finder.app"

    private let query = NSMetadataQuery()
    private let onUpdate: (AppCatalog) -> Void

    init(onUpdate: @escaping (AppCatalog) -> Void) {
        self.onUpdate = onUpdate
        super.init()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemContentTypeKey, "com.apple.application-bundle")
        query.searchScopes = Self.folders
        query.valueListAttributes = [NSMetadataItemPathKey, NSMetadataItemDisplayNameKey, NSMetadataItemCFBundleIdentifierKey, NSMetadataItemLastUsedDateKey]
        NotificationCenter.default.addObserver(self, selector: #selector(publish), name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(publish), name: .NSMetadataQueryDidUpdate, object: query)
        query.start()
    }

    @objc private func publish() {
        query.disableUpdates()
        defer { query.enableUpdates() }
        let apps = query.results.compactMap { result -> (bundleID: String, priority: Int, item: Item, lastUsed: Date?)? in
            guard let item = result as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
            else { return nil }
            let url = URL(filePath: path)
            guard !url.deletingLastPathComponent().pathComponents.contains(where: { $0.hasSuffix(".app") }) else { return nil }
            let title = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
            let bundleID = item.value(forAttribute: NSMetadataItemCFBundleIdentifierKey) as? String ?? path
            let priority = Self.preferredFolders.firstIndex { path.hasPrefix($0) } ?? Self.preferredFolders.count
            let lastUsed = item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
            return (bundleID, priority, Item(id: path, title: title, icon: .file(url), action: .open(url)), lastUsed)
        }
        let preferred = Dictionary(apps.map { ($0.bundleID, $0) }, uniquingKeysWith: { $0.priority <= $1.priority ? $0 : $1 })
        let finderURL = URL(filePath: Self.finderPath)
        let finder = Item(id: Self.finderPath, title: FileManager.default.displayName(atPath: Self.finderPath), icon: .file(finderURL), action: .open(finderURL))
        onUpdate(AppCatalog(preferred.values.map { ($0.item, $0.lastUsed) } + [(finder, nil)]))
    }
}
