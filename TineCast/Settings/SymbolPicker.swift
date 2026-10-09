import SwiftUI
import TineCastKit

extension SymbolCatalog {
    nonisolated static let system = Task.detached(priority: .userInitiated) { () -> SymbolCatalog? in
        let folder = URL(filePath: "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources")
        return try? SymbolCatalog(
            order: Data(contentsOf: folder.appending(path: "symbol_order.plist")),
            categories: Data(contentsOf: folder.appending(path: "categories.plist")),
            symbolCategories: Data(contentsOf: folder.appending(path: "symbol_categories.plist")),
            keywords: Data(contentsOf: folder.appending(path: "symbol_search.plist")),
            restrictions: Data(contentsOf: folder.appending(path: "symbol_restrictions.strings")),
            availability: Data(contentsOf: folder.appending(path: "name_availability.plist")),
            macOS: ProcessInfo.processInfo.operatingSystemVersion
        )
    }
}

struct SymbolButton: View {
    @Binding var symbol: String
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            Image(systemName: symbol)
                .imageScale(.large)
                .frame(width: 32, height: 32)
                .background(.fill.tertiary, in: .rect(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator)
                }
                .contentShape(.rect(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Icon")
        .accessibilityValue(symbol)
        .help("Choose an icon")
        .popover(isPresented: $isPicking, arrowEdge: .trailing) {
            SymbolPicker(symbol: $symbol) { isPicking = false }
        }
        #if DEBUG
        .task {
            guard SettingsSnapshot.requested?.presentation == .picker else { return }
            try? await Task.sleep(for: .milliseconds(300))
            isPicking = true
        }
        #endif
    }
}

private struct SymbolPicker: View {
    @Binding var symbol: String
    let done: () -> Void
    @State private var search = ""
    @State private var catalog: SymbolCatalog?
    @State private var isLoading = true

    var body: some View {
        let sections = sections(for: search.trimmingCharacters(in: .whitespacesAndNewlines))
        VStack(spacing: 0) {
            SearchField(prompt: "Search Symbols", text: $search)
                .padding(12)
            Divider()
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 9), spacing: 4) {
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.symbols, id: \.self) { name in
                                    SymbolCell(name: name, isSelected: name == symbol) {
                                        symbol = name
                                        done()
                                    }
                                }
                            } header: {
                                if !section.title.isEmpty {
                                    Label(section.title, systemImage: section.icon)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, section.id == sections.first?.id ? 0 : 12)
                                        .padding(.bottom, 2)
                                        .accessibilityAddTraits(.isHeader)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 360, height: 420)
        .task {
            catalog = await SymbolCatalog.system.value
            isLoading = false
        }
    }

    private func sections(for query: String) -> [SymbolCatalog.Section] {
        let selected = SymbolCatalog.Section(id: "selected", title: "Selected", icon: "checkmark.circle", symbols: [symbol])
        guard let catalog else {
            let isNamed = query != symbol && NSImage(systemSymbolName: query, accessibilityDescription: nil) != nil
            return [selected] + (isNamed ? [SymbolCatalog.Section(id: "name", title: "Symbol Name", icon: "character.cursor.ibeam", symbols: [query])] : [])
        }
        guard query.isEmpty else {
            return [SymbolCatalog.Section(id: "results", title: "", icon: "", symbols: catalog.search(query))].filter { !$0.symbols.isEmpty }
        }
        return [selected] + catalog.sections
    }
}

private struct SymbolCell: View {
    let name: String
    let isSelected: Bool
    let pick: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: pick) {
            Image(systemName: name)
                .font(.title3)
                .frame(width: 32, height: 32)
                .foregroundStyle(isSelected ? Color.white : .primary)
                .background(isSelected ? Color.accentColor : .primary.opacity(isHovering ? 0.08 : 0), in: .rect(cornerRadius: 7, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
