import SwiftUI
import TinecastKit

extension Animation {
    static let launcher = Animation.smooth(duration: 0.3)
}

struct LauncherView: View {
    static let margin: CGFloat = 40
    static let windowSize = CGSize(
        width: glassWidth + 2 * margin,
        height: barHeight + 1 + ResultsList.maximumHeight + 2 * margin
    )
    private static let glassWidth: CGFloat = 680
    private static let barHeight: CGFloat = 56

    let model: LauncherModel
    let run: (Item) -> Void
    let cancel: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        GlassEffectContainer {
            if model.isPresented {
                VStack(spacing: 0) {
                    searchBar
                    if !model.results.isEmpty {
                        Divider()
                        ResultsList(model: model, run: run)
                    } else if model.showsNoResults {
                        Divider()
                        Text("No Results")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: ResultsList.rowHeight)
                            .padding(ResultsList.inset)
                    }
                }
                .frame(width: Self.glassWidth)
                .fixedSize(horizontal: false, vertical: true)
                .glassEffect(.regular, in: .rect(cornerRadius: model.results.isEmpty && !model.showsNoResults ? Self.barHeight / 2 : 24))
                .glassEffectTransition(.materialize)
            }
        }
        .animation(reduceMotion ? nil : .launcher, value: model.results)
        .animation(reduceMotion ? nil : .launcher, value: model.showsNoResults)
        .padding(Self.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var searchBar: some View {
        HStack(spacing: ResultRow.iconSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .frame(width: ResultRow.iconSize)
                .accessibilityHidden(true)
            TextField("Search", text: Binding(get: { model.query }, set: { model.edit($0) }))
                .textFieldStyle(.plain)
                .accessibilityLabel("Search")
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
            Menu {
                Button("Settings…", action: openSettings)
                    .keyboardShortcut(",")
                Divider()
                Button("Quit tinecast", action: quit)
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.medium)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .font(.body)
            .foregroundStyle(.secondary)
            .accessibilityLabel("More")
        }
        .font(.title)
        .padding(.horizontal, ResultsList.inset + ResultRow.horizontalPadding)
        .frame(height: Self.barHeight)
    }
}
