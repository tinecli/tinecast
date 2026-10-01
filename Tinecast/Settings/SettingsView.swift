import SwiftUI

private enum Pane: String, CaseIterable, Identifiable {
    case general = "General"
    case launcher = "Launcher"
    case commands = "Commands"
    case permissions = "Permissions"

    var id: Self { self }
}

struct SettingsView: View {
    let model: SettingsModel
    @State private var pane = Pane.general

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(Pane.allCases, selection: $pane) { pane in
                Text(pane.rawValue)
            }
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(180)
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
        .frame(width: 720, height: 560)
    }

    @ViewBuilder private var detail: some View {
        if pane == .general {
            GeneralSettings(model: model)
        } else if pane == .launcher {
            LauncherSettings(model: model)
        } else if pane == .commands {
            CommandsSettings(model: model)
        } else {
            PermissionsSettings()
        }
    }
}
