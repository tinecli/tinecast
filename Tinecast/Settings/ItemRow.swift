import SwiftUI
import TinecastKit

struct ItemRowValue: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: Icon
    let alias: String?
    let isHidden: Bool
}

enum ItemScope: String, CaseIterable, Identifiable {
    case all = "All"
    case withAlias = "With Alias"
    case hidden = "Hidden"

    var id: Self { self }

    func rows(of items: [Item], matching query: String, aliases: [String: String], hidden: Set<String>) -> [ItemRowValue] {
        items.compactMap { item in
            let alias = aliases[item.id]
            let isHidden = hidden.contains(item.id)
            guard self != .withAlias || alias != nil, self != .hidden || isHidden else { return nil }
            guard query.isEmpty || item.title.localizedStandardContains(query) || alias?.localizedStandardContains(query) == true else { return nil }
            return ItemRowValue(id: item.id, title: item.title, icon: item.icon, alias: alias, isHidden: isHidden)
        }
    }
}

struct ItemRow<Leading: View>: View {
    let value: ItemRowValue
    var note: String?
    let model: SettingsModel
    @ViewBuilder let leading: Leading

    var body: some View {
        HStack(spacing: 8) {
            leading
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(value.title)
                .lineLimit(1)
                .foregroundStyle(value.isHidden ? .secondary : .primary)
            Spacer(minLength: 12)
            if let note {
                Text(note)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            AliasField(id: value.id, title: value.title, alias: value.alias, model: model)
            Toggle("Show", isOn: Binding(get: { !value.isHidden }, set: { model.setHidden(!$0, for: value.id) }))
                .toggleStyle(.checkbox)
                .accessibilityLabel("Show \(value.title) in Search")
        }
    }
}

private struct AliasField: View {
    let id: String
    let title: String
    let alias: String?
    let model: SettingsModel
    @State private var text: String
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    init(id: String, title: String, alias: String?, model: SettingsModel) {
        self.id = id
        self.title = title
        self.alias = alias
        self.model = model
        _text = State(initialValue: alias ?? "")
    }

    var body: some View {
        TextField("Alias for \(title)", text: $text, prompt: Text("Alias"))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .frame(width: 110)
            .overlay(alignment: .trailing) {
                if (isHovering || isFocused) && !text.isEmpty {
                    Button("Clear Alias", systemImage: "xmark.circle.fill") {
                        text = ""
                        commit()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear Alias")
                    .padding(.trailing, 4)
                }
            }
            .onHover { isHovering = $0 }
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onChange(of: alias) { _, saved in
                if !isFocused { text = saved ?? "" }
            }
            .onDisappear(perform: commit)
    }

    private func commit() {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines) != (alias ?? "") else { return }
        model.setAlias(text, for: id)
    }
}
