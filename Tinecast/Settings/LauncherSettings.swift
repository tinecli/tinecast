import SwiftUI
import TinecastKit

private enum Scope: String, CaseIterable, Identifiable {
    case all = "All"
    case applications = "Applications"
    case system = "System"
    case commands = "Commands"
    case withAlias = "With Alias"
    case hidden = "Hidden"

    var id: Self { self }

    func includes(_ item: Item, aliases: [String: String], hidden: Set<String>) -> Bool {
        if self == .applications { return item.kind == "Application" }
        if self == .system { return item.kind == "System" }
        if self == .commands { return item.kind == "Command" }
        if self == .withAlias { return aliases[item.id] != nil }
        if self == .hidden { return hidden.contains(item.id) }
        return true
    }
}

struct LauncherSettings: View {
    private static let sections = [("Applications", "Application"), ("System", "System"), ("Commands", "Command")]

    @Bindable var model: SettingsModel
    @State private var search = ""
    @State private var scope = Scope.all

    var body: some View {
        let aliases = model.config.aliases
        let hidden = Set(model.config.hiddenItems)
        let query = search.trimmingCharacters(in: .whitespaces)
        let matches = model.items.filter { item in
            scope.includes(item, aliases: aliases, hidden: hidden)
                && (query.isEmpty || item.title.localizedStandardContains(query) || aliases[item.id]?.localizedStandardContains(query) == true)
        }
        let sections = Self.sections
            .map { title, kind in (title: title, items: matches.filter { $0.kind == kind }) }
            .filter { !$0.items.isEmpty }
        Form {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        LauncherRow(model: model, item: item, isHidden: hidden.contains(item.id))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .overlay {
            if sections.isEmpty {
                if query.isEmpty {
                    Text("No Items")
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search by name or alias")
        .toolbar {
            ToolbarItem {
                Picker("Show", selection: $scope) {
                    ForEach(Scope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

private struct LauncherRow: View {
    @Bindable var model: SettingsModel
    let item: Item
    let isHidden: Bool

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            Text(item.title)
                .lineLimit(1)
                .foregroundStyle(isHidden ? .secondary : .primary)
            Spacer(minLength: 12)
            AliasField(model: model, itemID: item.id, label: "Alias for \(item.title)")
            Toggle("Show \(item.title) in Launcher", isOn: Binding(
                get: { !isHidden },
                set: { model.config.setHidden(!$0, for: item.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .help("Show in Launcher")
        }
    }

    @ViewBuilder private var icon: some View {
        if case .symbol(let name) = item.icon {
            Image(systemName: name)
                .foregroundStyle(.secondary)
        } else {
            ItemIcon(icon: item.icon)
        }
    }
}
