import AppKit

final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()

    func icon(forPath path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}
