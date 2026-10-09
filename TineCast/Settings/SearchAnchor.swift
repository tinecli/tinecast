import SwiftUI

struct SearchReveal: Equatable {
    let anchor: String?
    let filter: String?
    private let token = UUID()

    init(_ result: SearchResult) {
        anchor = result.anchor
        filter = result.filter
    }
}

extension EnvironmentValues {
    @Entry var searchReveal: SearchReveal?
}

struct SearchAnchor: ViewModifier {
    let id: String
    @Environment(\.searchReveal) private var reveal
    @State private var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.tint.opacity(isHighlighted ? 0.14 : 0))
                    .padding(-6)
            }
            .id(id)
            .task(id: reveal) {
                guard reveal?.anchor == id else { return }
                isHighlighted = true
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.easeOut(duration: 0.6)) { isHighlighted = false }
            }
    }
}
