import SwiftUI
import TinecastKit

struct SystemActionsSettings: View {
    private static let groups: [(title: String, items: [Item])] = ([
        ("Power", [.lockScreen, .sleep, .sleepDisplays, .restart, .shutDown, .logOut, .startScreenSaver]),
        ("Media", [.playPause, .nextTrack, .previousTrack, .volumeUp, .volumeDown, .toggleMute]),
        ("Desktop & Finder", [.showDesktop, .toggleDarkMode, .openTrash, .emptyTrash, .ejectAllDisks]),
        ("Apps", [.hideOtherApps, .showAllApps, .quitAllApps]),
    ] as [(String, [SystemAction])]).map { title, actions in (title, actions.map(\.item)) }
    private static let asksFirst: Set<String> = Set([SystemAction.restart, .shutDown, .logOut, .emptyTrash, .quitAllApps].map(\.item.id))

    let model: SettingsModel
    @State private var filter = ""
    @State private var scope = ItemScope.all
    @State private var sections: [(title: String, rows: [ItemRowValue])] = []

    var body: some View {
        List {
            PaneHeader(pane: .systemActions)
                .listRowSeparator(.hidden)
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in
                        ItemRow(value: row, note: Self.asksFirst.contains(row.id) ? "Asks First" : nil, model: model) {
                            if case .symbol(let name) = row.icon {
                                PaneTile(symbol: name, color: Pane.systemActions.color, size: 20)
                                    .symbolVariant(.fill)
                            }
                        }
                    }
                }
            }
            if sections.isEmpty {
                emptyResult
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.inset)
        .safeAreaInset(edge: .top, spacing: 0) {
            FilterBar(prompt: "Filter System Actions", text: $filter, scope: $scope)
        }
        .onChange(of: filter, initial: true, updateSections)
        .onChange(of: scope, updateSections)
        .onChange(of: model.config.aliases, updateSections)
        .onChange(of: model.config.hiddenItems, updateSections)
    }

    @ViewBuilder private var emptyResult: some View {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else if scope == .withAlias {
            ContentUnavailableView("No Aliases", systemImage: "character.cursor.ibeam", description: Text("Actions you give an alias appear here."))
        } else if scope == .hidden {
            ContentUnavailableView("No Hidden Actions", systemImage: "eye.slash", description: Text("Actions you hide from search appear here."))
        }
    }

    private func updateSections() {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        let hidden = Set(model.config.hiddenItems)
        sections = Self.groups
            .map { group in (group.title, scope.rows(of: group.items, matching: query, aliases: model.config.aliases, hidden: hidden)) }
            .filter { !$0.rows.isEmpty }
    }
}
