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

    func repairIndex() async throws -> Int {
        let missing = unindexedBundlePaths()
        guard !missing.isEmpty else { return 0 }
        if let failure = try await failureOutput(of: "/usr/bin/mdimport", missing) { throw IndexRepairFailure(errorDescription: failure) }
        return missing.count
    }

    private func unindexedBundlePaths() -> [String] {
        let indexed = Set(query.results.compactMap { ($0 as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String })
        return Self.folders.flatMap { folder in
            let entries = ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []).map { (folder as NSString).appendingPathComponent($0) }
            let nested = entries.filter { !$0.hasSuffix(".app") }.flatMap { subfolder in
                ((try? FileManager.default.contentsOfDirectory(atPath: subfolder)) ?? []).map { (subfolder as NSString).appendingPathComponent($0) }
            }
            return (entries + nested).filter { $0.hasSuffix(".app") && !indexed.contains($0) }
        }
    }

    @objc private func publish() {
        query.disableUpdates()
        defer { query.enableUpdates() }
        let indexed = query.results.compactMap { result -> (path: String, name: String, bundleID: String?, lastUsed: Date?)? in
            guard let item = result as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
            else { return nil }
            return (path, name, item.value(forAttribute: NSMetadataItemCFBundleIdentifierKey) as? String, item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date)
        }
        let unindexed = unindexedBundlePaths().map { path -> (path: String, name: String, bundleID: String?, lastUsed: Date?) in
            (path, FileManager.default.displayName(atPath: path), Bundle(path: path)?.bundleIdentifier, nil)
        }
        let apps = (indexed + unindexed).compactMap { app -> (bundleID: String, priority: Int, item: Item, lastUsed: Date?)? in
            let url = URL(filePath: app.path)
            guard !url.deletingLastPathComponent().pathComponents.contains(where: { $0.hasSuffix(".app") }) else { return nil }
            let title = app.name.hasSuffix(".app") ? String(app.name.dropLast(4)) : app.name
            let priority = Self.preferredFolders.firstIndex { app.path.hasPrefix($0) } ?? Self.preferredFolders.count
            return (app.bundleID ?? app.path, priority, Item(id: app.path, title: title, icon: .file(url), action: .open(url)), app.lastUsed)
        }
        let preferred = Dictionary(apps.map { ($0.bundleID, $0) }, uniquingKeysWith: { $0.priority <= $1.priority ? $0 : $1 })
        let finderURL = URL(filePath: Self.finderPath)
        let finder = Item(id: Self.finderPath, title: FileManager.default.displayName(atPath: Self.finderPath), icon: .file(finderURL), action: .open(finderURL))
        onUpdate(AppCatalog(preferred.values.map { ($0.item, $0.lastUsed) } + [(finder, nil)]))
    }
}

private struct IndexRepairFailure: LocalizedError {
    let errorDescription: String?
}
