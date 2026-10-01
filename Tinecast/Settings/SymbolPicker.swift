import SwiftUI
import TinecastKit

struct SymbolButton: View {
    @Binding var symbol: String
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            Image(systemName: symbol)
                .frame(width: 28, height: 20)
        }
        .accessibilityLabel("Icon")
        .accessibilityValue(symbol)
        .help("Choose an icon")
        .popover(isPresented: $isPicking, arrowEdge: .trailing) {
            SymbolPicker(symbol: $symbol) { isPicking = false }
        }
    }
}

private struct SymbolPicker: View {
    @Binding var symbol: String
    let done: () -> Void
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search", text: $search, prompt: Text("Search symbols"))
                .textFieldStyle(.roundedBorder)
                .padding(12)
            Divider()
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 9), alignment: .leading, spacing: 4, pinnedViews: .sectionHeaders) {
                    ForEach(groups, id: \.title) { group in
                        Section {
                            ForEach(group.symbols, id: \.self, content: cell)
                        } header: {
                            Text(group.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .background(.background)
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 352, height: 380)
    }

    private var groups: [SymbolGroup] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return commandSymbolGroups }
        let matches = commandSymbolGroups
            .map { SymbolGroup(title: $0.title, symbols: $0.symbols.filter { $0.localizedStandardContains(query) || $0.replacing(".", with: " ").localizedStandardContains(query) }) }
            .filter { !$0.symbols.isEmpty }
        let isKnown = commandSymbolGroups.contains { $0.symbols.contains(query) }
        guard !isKnown, NSImage(systemSymbolName: query, accessibilityDescription: nil) != nil else { return matches }
        return [SymbolGroup(title: "Symbol Name", symbols: [query])] + matches
    }

    private func cell(_ name: String) -> some View {
        let isSelected = name == symbol
        return Button {
            symbol = name
            done()
        } label: {
            Image(systemName: name)
                .font(.title3)
                .frame(width: 32, height: 32)
                .foregroundStyle(isSelected ? Color.white : .primary)
                .background(isSelected ? Color.accentColor : .clear, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
