import SwiftUI
import TinecastKit

extension Animation {
    static let launcher = Animation.smooth(duration: 0.12)
}

struct Surface<S: Shape>: ViewModifier {
    let material: Config.Material
    let shape: S

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, colorScheme)
            .environment(\.appearsActive, true)
            .environment(\.backgroundMaterial, nil)
            .background {
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
    static let cornerRadius: CGFloat = 24

    let model: LauncherModel
    let run: (Item) -> Void
    let reveal: (Item) -> Void
    let cancel: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var resultsHeight: CGFloat {
        if !model.config.compact { return ResultsList.maximumContentHeight }
        if model.showsNoResults { return ResultsList.rowHeight }
        let content = CGFloat(model.results.count) * ResultsList.rowHeight + CGFloat(model.sections.count) * ResultsList.headerHeight
        return min(content, ResultsList.maximumContentHeight)
    }

    var body: some View {
        GlassEffectContainer {
            if model.isPresented {
                VStack(spacing: 0) {
                    searchBar
                    if resultsHeight > 0 {
                        Divider()
                        ResultsList(
                            model: model,
                            contentHeight: resultsHeight,
                            run: run,
                            actionBar: ActionBar(
                                item: model.selectedItem,
                                run: run,
                                reveal: reveal,
                                openSettings: openSettings,
                                quit: quit
                            )
                        )
                    }
                }
                .frame(width: Self.glassWidth)
                .fixedSize(horizontal: false, vertical: true)
                .clipShape(.rect(cornerRadius: Self.cornerRadius))
                .modifier(Surface(material: model.config.material, shape: .rect(cornerRadius: Self.cornerRadius)))
                .glassEffectTransition(.materialize)
            }
        }
        .animation(model.config.compact ? .launcher : nil, value: resultsHeight > 0)
        .padding(Self.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: model.isPresented) { _, isPresented in
            guard isPresented else { return }
            isSearchFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: ResultRow.iconSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.5))
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
