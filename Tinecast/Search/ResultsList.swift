import SwiftUI
import TinecastKit

struct ResultsList: View {
    static let rowHeight: CGFloat = 40
    static let inset: CGFloat = 8
    static let maximumHeight = CGFloat(visibleRows) * rowHeight + inset * 2
    private static let visibleRows = 8

    let model: LauncherModel
    let run: (Item) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.results) { item in
                        let isSelected = item.id == model.selectedItem?.id
                        Button { run(item) } label: {
                            ResultRow(item: item, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                        .frame(height: Self.rowHeight)
                        .accessibilityLabel(item.subtitle.map { "\(item.title), \($0)" } ?? item.title)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(Self.inset)
            }
            .frame(height: CGFloat(min(model.results.count, Self.visibleRows)) * Self.rowHeight + Self.inset * 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(model.query.isEmpty ? "Suggestions" : "Results")
            .onChange(of: model.selectedItem) { _, item in
                guard let item else { return }
                proxy.scrollTo(item.id)
                guard model.isPresented else { return }
                AccessibilityNotification.Announcement(item.subtitle.map { "\(item.title), \($0)" } ?? item.title).post()
            }
        }
    }
}
