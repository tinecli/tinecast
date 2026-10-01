import SwiftUI
import TinecastKit

struct AliasesSettings: View {
    @Bindable var model: SettingsModel
    @State private var rowIDs: Set<String> = []
    @State private var selection: Set<String> = []
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Table(rows, selection: $selection) {
                TableColumn("Name") { item in
                    Label {
                        Text(item.title)
                    } icon: {
                        ItemIcon(icon: item.icon)
                            .frame(width: 16, height: 16)
                    }
                    .lineLimit(1)
                }
                TableColumn("Kind") { item in
                    Text(item.kind ?? "")
                        .foregroundStyle(.secondary)
                }
                .width(90)
                TableColumn("Alias") { item in
                    AliasField(model: model, itemID: item.id, label: "Alias for \(item.title)")
                        .labelsHidden()
                }
                .width(120)
                TableColumn("Hidden") { item in
                    Toggle("Hide \(item.title)", isOn: hiddenBinding(for: item.id))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
                .width(50)
            }
            .accessibilityLabel("Aliases and hidden items")
            HStack {
                Button("Add…") { isAdding = true }
                Button("Remove", action: removeSelection)
                    .disabled(selection.isEmpty)
                Spacer()
                Text("An alias opens its item when typed exactly. Hidden items don't appear in search.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .onChange(of: customizedIDs, initial: true) {
            rowIDs.formUnion(customizedIDs)
        }
        .sheet(isPresented: $isAdding) {
            ItemChooser(items: model.items.filter { !rowIDs.contains($0.id) }) { id in
                rowIDs.insert(id)
                selection = [id]
            }
        }
    }

    private var customizedIDs: Set<String> {
        Set(model.config.aliases.keys).union(model.config.hiddenItems)
    }

    private var rows: [Item] {
        let known = Dictionary(model.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return rowIDs
            .map { id in known[id] ?? Item(id: id, title: (id as NSString).lastPathComponent, icon: .file(URL(filePath: id)), action: .open(URL(filePath: id))) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func hiddenBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { model.config.hiddenItems.contains(id) },
            set: { model.config.setHidden($0, for: id) }
        )
    }

    private func removeSelection() {
        for id in selection {
            model.config.setAlias("", for: id)
            model.config.setHidden(false, for: id)
        }
        rowIDs.subtract(selection)
        selection = []
    }
}

private struct ItemChooser: View {
    let items: [Item]
    let choose: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add an Item")
                .font(.headline)
            TextField("Search", text: $search, prompt: Text("Search apps, commands and system actions"))
                .textFieldStyle(.roundedBorder)
            List(matches, selection: $selection) { item in
                HStack {
                    Label {
                        Text(item.title)
                    } icon: {
                        ItemIcon(icon: item.icon)
                            .frame(width: 16, height: 16)
                    }
                    Spacer()
                    Text(item.kind ?? "")
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .tag(item.id)
            }
            .listStyle(.bordered(alternatesRowBackgrounds: false))
            .contextMenu(forSelectionType: String.self) { _ in } primaryAction: { ids in
                guard let id = ids.first else { return }
                add(id)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    guard let selection else { return }
                    add(selection)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
        }
        .padding(20)
        .frame(width: 420, height: 440)
    }

    private var matches: [Item] {
        search.trimmingCharacters(in: .whitespaces).isEmpty ? items : rank(items, query: search)
    }

    private func add(_ id: String) {
        choose(id)
        dismiss()
    }
}
