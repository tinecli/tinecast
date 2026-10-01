import SwiftUI

struct ApplicationsSettings: View {
    let model: SettingsModel
    @State private var filter = ""
    @State private var scope = ItemScope.all
    @State private var rows: [ItemRowValue] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsCard {
                    PaneHeader(pane: .applications)
                    FilterBar(prompt: "Filter Applications", text: $filter, scope: $scope)
                }
                if rows.isEmpty {
                    emptyResult
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    SettingsCard {
                        ForEach(rows) { row in
                            ItemRow(value: row, model: model) {
                                ItemIcon(icon: row.icon)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: filter, initial: true, updateRows)
        .onChange(of: scope, updateRows)
        .onChange(of: model.applications, updateRows)
        .onChange(of: model.config.aliases, updateRows)
        .onChange(of: model.config.hiddenItems, updateRows)
    }

    @ViewBuilder private var emptyResult: some View {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else if scope == .withAlias {
            ContentUnavailableView("No Aliases", systemImage: "character.cursor.ibeam", description: Text("Apps you give an alias appear here."))
        } else if scope == .hidden {
            ContentUnavailableView("No Hidden Apps", systemImage: "eye.slash", description: Text("Apps you hide from search appear here."))
        }
    }

    private func updateRows() {
        rows = scope.rows(
            of: model.applications,
            matching: filter.trimmingCharacters(in: .whitespacesAndNewlines),
            aliases: model.config.aliases,
            hidden: Set(model.config.hiddenItems)
        )
    }
}
