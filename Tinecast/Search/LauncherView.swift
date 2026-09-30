import SwiftUI
import TinecastKit

struct LauncherView: View {
    @Bindable var model: LauncherModel
    let run: (Item) -> Void
    let reveal: (Item) -> Void
    let cancel: () -> Void
    let resize: (CGSize) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        guard let item = model.selectedItem else { return }
                        run(item)
                    }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        guard let item = model.selectedItem else { return .handled }
                        reveal(item)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        model.moveSelection(by: -1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        model.moveSelection(by: 1)
                        return .handled
                    }
                    .onExitCommand(perform: cancel)
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
