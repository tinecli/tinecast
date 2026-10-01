import SwiftUI

private enum Pane: String, CaseIterable, Identifiable {
    case general = "General"
    case commands = "Commands"
    case aliases = "Aliases"
    case permissions = "Permissions"

    var id: Self { self }

    var tile: (symbol: String, color: Color) {
        if self == .general { return ("gearshape.fill", .gray) }
        if self == .commands { return ("terminal.fill", Color(white: 0.2)) }
        if self == .aliases { return ("character.cursor.ibeam", .indigo) }
        return ("hand.raised.fill", .blue)
    }
}

struct SettingsView: View {
    let model: SettingsModel
    @State private var pane = Pane.general

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $pane) {
                ForEach(Pane.allCases) { pane in
                    Label { Text(pane.rawValue) } icon: { Tile(symbol: pane.tile.symbol, color: pane.tile.color) }
                }
            }
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            detail
                .navigationTitle(pane.rawValue)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let problem = model.fileProblem {
                        HStack(alignment: .firstTextBaseline) {
                            Label {
                                Text("Changes aren't saved until settings.json is fixed. \(problem)")
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Button("Open settings.json", action: model.openFile)
                        }
                        .padding(12)
                        .background(.bar)
                    }
                }
        }
        .frame(width: 715, height: 600)
    }

    @ViewBuilder private var detail: some View {
        if pane == .general {
            GeneralSettings(model: model)
        } else if pane == .commands {
            CommandsSettings(model: model)
        } else if pane == .aliases {
            AliasesSettings(model: model)
        } else {
            PermissionsSettings(model: model)
        }
    }
}
