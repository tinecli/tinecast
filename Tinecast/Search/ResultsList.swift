import SwiftUI
import TinecastKit

struct ResultsList: View {
    static let rowHeight: CGFloat = 40
    static let headerHeight: CGFloat = 28
    static let inset: CGFloat = 8
    static let visibleRows = 8
    static let maximumContentHeight = CGFloat(visibleRows) * rowHeight
    static let maximumHeight = maximumContentHeight + inset * 2 + ActionBar.height

    let model: LauncherModel
    let contentHeight: CGFloat
    let run: (Item) -> Void
    let actionBar: ActionBar

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.showsNoResults {
                        Text("No Results")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Self.rowHeight)
                    }
                    ForEach(model.results.indices, id: \.self) { index in
                        VStack(spacing: 0) {
                            if let section = model.sections.first(where: { $0.start == index }) {
                                header(section.title)
                            }
                            row(at: index)
                        }
                    }
                }
                .padding(Self.inset)
            }
            .scrollIndicators(.never)
            .safeAreaBar(edge: .bottom) { actionBar }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .frame(height: contentHeight + Self.inset * 2 + ActionBar.height)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(model.query.isEmpty ? "Suggestions" : "Results")
            .onChange(of: model.selectedIndex) { _, index in
                proxy.scrollTo(index)
            }
            .onChange(of: model.selectedItem) { _, item in
                guard let item else { return }
                proxy.scrollTo(model.selectedIndex)
                guard model.isPresented else { return }
                AccessibilityNotification.Announcement(item.subtitle.map { "\(item.title), \($0)" } ?? item.title).post()
            }
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, ResultRow.horizontalPadding)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.headerHeight, alignment: .bottom)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(at index: Int) -> some View {
        let item = model.results[index]
        let isSelected = index == model.selectedIndex
        let calculation: Calculation? = if case .copy = item.action { model.calculation } else { nil }
        return Button { run(item) } label: {
            if let calculation {
                CalculatorCard(calculation: calculation, isSelected: isSelected)
            } else {
                ResultRow(item: item, alias: model.config.aliases[item.id], isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
        .frame(height: calculation == nil ? Self.rowHeight : CalculatorCard.height)
        .accessibilityLabel(item.subtitle.map { "\(item.title), \($0)" } ?? item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
