import SwiftUI
import TinecastKit

struct ItemIcon: View {
    private static let cache = NSCache<NSString, NSImage>()

    let icon: Icon

    var body: some View {
        switch icon {
        case .file(let url):
            Image(nsImage: Self.fileIcon(at: url.path(percentEncoded: false)))
                .resizable()
                .scaledToFit()
        case .symbol(let name):
            Image(systemName: name)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private static func fileIcon(at path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}
