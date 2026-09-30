import SwiftUI
import TinecastKit

extension Animation {
    static let launcher = Animation.smooth(duration: 0.18)
}

extension View {
    func surface(_ material: Config.Material, in shape: some Shape) -> some View {
        background {
            if material == .frosted {
                shape.fill(.thickMaterial).shadow(radius: 12, y: 4)
            }
        }
        .glassEffect(material == .glass ? .regular : .identity, in: shape)
    }
}

struct LauncherView: View {
    static let margin: CGFloat = 40
    static let windowSize = CGSize(
        width: glassWidth + 2 * margin,
        height: barHeight + 1 + ResultsList.maximumHeight + 2 * margin
    )
    private static let glassWidth: CGFloat = 680
    private static let barHeight: CGFloat = 56
    private static let cornerRadius: CGFloat = 24

    let model: LauncherModel
    let run: (Item) -> Void
    let reveal: (Item) -> Void
    let cancel: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    @FocusState private var isSearchFocused: Bool

    private var visibleRowCount: Int {
        model.results.isEmpty ? (model.showsNoResults ? 1 : 0) : min(model.results.count, ResultsList.visibleRows)
    }

    var body: some View {
        GlassEffectContainer {
            if model.isPresented {
                VStack(spacing: 0) {
                    searchBar
                    if visibleRowCount > 0 {
                        Divider()
                        ResultsList(model: model, visibleRowCount: visibleRowCount, run: run)
                    }
                }
                .frame(width: Self.glassWidth)
                .fixedSize(horizontal: false, vertical: true)
                .clipShape(.rect(cornerRadius: Self.cornerRadius))
                .surface(model.config.material, in: .rect(cornerRadius: Self.cornerRadius))
                .glassEffectTransition(.materialize)
            }
        }
        .overlay(alignment: .bottom) {
            if model.isPresented && visibleRowCount > 0 {
                ActionBar(
                    item: model.selectedItem,
                    material: model.config.material,
                    run: run,
                    reveal: reveal,
                    openSettings: openSettings,
                    quit: quit
                )
            }
        }
        .padding(Self.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var searchBar: some View {
        HStack(spacing: ResultRow.iconSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .frame(width: ResultRow.iconSize)
                .accessibilityHidden(true)
            TextField(
                "Search",
                text: Binding(get: { model.query }, set: { model.edit($0) }),
                prompt: Text("Search").foregroundStyle(.secondary)
            )
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
            .onAppear { isSearchFocused = true }
            .onSubmit {
                guard let item = model.selectedItem else { return }
                run(item)
            }
            .onKeyPress(.upArrow) {
                model.moveUp()
                return .handled
            }
            .onKeyPress(.downArrow) {
                model.moveDown()
                return .handled
            }
            .onExitCommand(perform: cancel)
        }
        .font(.title)
        .padding(.horizontal, ResultsList.inset + ResultRow.horizontalPadding)
        .frame(height: Self.barHeight)
    }
}
