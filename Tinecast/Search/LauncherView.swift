import SwiftUI
import TinecastKit

struct LauncherView: View {
    let model: LauncherModel
    let run: (Item) -> Void
    let cancel: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void
    let resize: (CGSize) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search", text: Binding(get: { model.query }, set: { model.edit($0) }))
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search")
                    .focused($isSearchFocused)
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
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)
                .accessibilityLabel("More")
            }
            .font(.title2)
            .padding(.horizontal, 20)
            .frame(height: 56)

            if !model.results.isEmpty {
                Divider()
                ResultsList(model: model, run: run)
            }
        }
        .frame(width: 680)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .scaleEffect(model.isPresented || reduceMotion ? 1 : 0.97, anchor: .top)
        .animation(.smooth(duration: 0.3), value: model.isPresented)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGSize.self, of: \.size, action: resize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: model.isPresented, initial: true) { isSearchFocused = model.isPresented }
    }
}
