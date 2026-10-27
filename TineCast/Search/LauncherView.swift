import AppKit
import SwiftUI
import TineCastKit

extension Animation {
    static let launcher = Animation.smooth(duration: 0.12)
}

struct Surface<S: Shape>: ViewModifier {
    let shape: S

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, colorScheme)
            .environment(\.appearsActive, true)
            .glassEffect(.regular, in: shape)
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
    let isRunning: (URL) -> Bool
    let showWindows: (Item) -> Void
    let cancel: () -> Void
    let showMoreMenu: (NSView) -> Void
    let actionsAnchor: NSView
    let showActions: () -> Void
    let registerOpenSettings: (OpenWindowAction) -> Void

    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openSettingsWindow

    private var resultsHeight: CGFloat {
        if !model.config.compact { return ResultsList.maximumContentHeight }
        let card = model.calculation == nil ? 0 : CalculatorCard.height - ResultsList.rowHeight
        let rows = model.results.count + (model.emptyMessage == nil ? 0 : 1)
        let content = CGFloat(rows) * ResultsList.rowHeight + card + CGFloat(model.sections.count) * ResultsList.headerHeight
        return min(content, ResultsList.maximumContentHeight)
    }

    var body: some View {
        GlassEffectContainer {
            if model.isPresented {
                VStack(spacing: 0) {
                    Group {
                        searchBar
                        if resultsHeight > 0 {
                            Divider()
                            ResultsList(
                                model: model,
                                contentHeight: resultsHeight,
                                run: run,
                                isRunning: isRunning,
                                actionBar: ActionBar(item: model.selectedItem, run: run, reveal: reveal, isRunning: isRunning, showWindows: showWindows, showMoreMenu: showMoreMenu, actionsAnchor: actionsAnchor, showActions: showActions)
                            )
                        }
                    }
                    // .glassEffect overrides a backgroundMaterial pin on its content; a pin on each child holds.
                    .environment(\.backgroundMaterial, nil)
                }
                .frame(width: Self.glassWidth)
                .fixedSize(horizontal: false, vertical: true)
                .clipShape(.rect(cornerRadius: Self.cornerRadius))
                .modifier(Surface(shape: .rect(cornerRadius: Self.cornerRadius)))
                .glassEffectTransition(.materialize)
            }
        }
        .animation(model.config.compact ? .launcher : nil, value: resultsHeight > 0)
        .padding(Self.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { registerOpenSettings(openSettingsWindow) }
        .onChange(of: model.isPresented) { _, isPresented in
            guard isPresented else { return }
            isSearchFocused = true
        }
    }

    private func escape() {
        if !model.query.isEmpty {
            model.edit("")
        } else if model.drilledApp != nil {
            withAnimation(.launcher) { model.leaveWindows() }
        } else {
            cancel()
        }
    }

    private static let searchFont: Font = {
        let base = NSFont.preferredFont(forTextStyle: .title1)
        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: [
            [NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType, .selectorIdentifier: kMonospacedNumbersSelector],
            [NSFontDescriptor.FeatureKey.typeIdentifier: kCaseSensitiveLayoutType, .selectorIdentifier: kCaseSensitiveLayoutOnSelector],
        ]])
        return Font(NSFont(descriptor: descriptor, size: base.pointSize) ?? base)
    }()

    private var searchBar: some View {
        let prompt = model.drilledApp == nil ? "Search" : "Search Windows"
        return HStack(spacing: ResultRow.iconSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.5))
                .frame(width: ResultRow.iconSize)
                .accessibilityHidden(true)
            if let app = model.drilledApp {
                HStack(spacing: 6) {
                    ItemIcon(icon: app.icon)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    Text(app.title)
                        .lineLimit(1)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((colorScheme == .dark ? Color.white : .black).opacity(0.08), in: .rect(cornerRadius: 5, style: .continuous))
                .fixedSize()
            }
            TextField(
                prompt,
                text: Binding(get: { model.query }, set: { model.edit($0) }),
                prompt: Text(prompt).foregroundStyle(.secondary)
            )
            .textFieldStyle(.plain)
            .font(Self.searchFont)
            .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
            .focused($isSearchFocused)
            .onAppear { isSearchFocused = true }
            .onSubmit {
                guard let item = model.selectedItem ?? model.drilledApp else { return }
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
            .onKeyPress(.rightArrow) {
                guard let item = model.selectedItem,
                      case .open(let url) = item.action,
                      isRunning(url),
                      let editor = NSApp.keyWindow?.firstResponder as? NSTextView,
                      editor.selectedRange() == NSRange(location: (editor.string as NSString).length, length: 0)
                else { return .ignored }
                showWindows(item)
                return .handled
            }
            .onExitCommand(perform: escape)
        }
        .font(.title)
        .padding(.horizontal, ResultsList.inset + ResultRow.horizontalPadding)
        .frame(height: Self.barHeight)
    }
}
