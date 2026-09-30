import SwiftUI
import TinecastKit

struct ResultsList: View {
    let model: LauncherModel
    let run: (Item) -> Void

    private static let rowHeight: CGFloat = 40
    private static let visibleRows = 8
    private static let inset: CGFloat = 8

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.results) { item in
                        ResultRow(item: item, isSelected: item.id == model.selectedItem?.id)
                            .frame(height: Self.rowHeight)
                            .onTapGesture { run(item) }
                            .accessibilityAction { run(item) }
                    }
                }
                .padding(Self.inset)
            }
            .frame(height: CGFloat(min(model.results.count, Self.visibleRows)) * Self.rowHeight + Self.inset * 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(model.query.isEmpty ? "Suggestions" : "Results")
            .onChange(of: model.selectedItem?.id) { _, id in
                guard let id else { return }
                proxy.scrollTo(id)
            }
        }
    }
}
