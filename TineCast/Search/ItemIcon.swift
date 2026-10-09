import SwiftUI
import TineCastKit

struct ItemIcon: View {
    let icon: Icon

    var body: some View {
        switch icon {
        case .file(let url):
            Image(nsImage: IconCache.shared.icon(forPath: url.path(percentEncoded: false)))
                .resizable()
                .scaledToFit()
        case .symbol(let name):
            Image(systemName: name)
                .symbolRenderingMode(.hierarchical)
        }
    }
}
