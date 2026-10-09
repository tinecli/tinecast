import SwiftUI

struct ApplicationsSettings: View {
    let model: SettingsModel
    @State private var filter = ""
    @State private var scope = ItemScope.all
    @Environment(\.searchReveal) private var reveal
    @State private var rows: [ItemRowValue] = []
    @State private var isRepairing = false
    @State private var repairStatus: String?
    @State private var repairFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsCard {
                    PaneHeader(pane: .applications)
                    FilterBar(prompt: "Filter Applications", text: $filter, scope: $scope)
                }
                SettingsCard {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Missing an App?")
                            Text(repairStatus ?? "Apps Spotlight hasn’t indexed still appear, but without recent use. Repair adds them to the index.")
                                .font(.callout)
                                .foregroundStyle(repairFailed ? .red : .secondary)
                        }
                        Spacer()
                        if isRepairing {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Repairing")
                        }
                        Button(SettingRow.repairAppIndex.label, action: repair)
                            .disabled(isRepairing)
                    }
                    .modifier(SearchAnchor(id: SettingRow.repairAppIndex.rawValue))
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
                            .modifier(SearchAnchor(id: row.id))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: filter, initial: true, updateRows)
        .onChange(of: reveal, initial: true, applyRevealFilter)
        .onChange(of: scope, updateRows)
        .onChange(of: model.applications, updateRows)
        .onChange(of: model.config.aliases, updateRows)
        .onChange(of: model.config.hiddenItems, updateRows)
    }

    private func repair() {
        isRepairing = true
        Task {
            do {
                let count = try await model.repairAppIndex()
                repairStatus = count == 0 ? "Every app is already indexed." : "Added \(count) \(count == 1 ? "app" : "apps") to the Spotlight index."
                repairFailed = false
            } catch {
                repairStatus = error.localizedDescription
                repairFailed = true
            }
            isRepairing = false
        }
    }

    private func applyRevealFilter() {
        guard let revealed = reveal?.filter else { return }
        filter = revealed
        scope = .all
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
