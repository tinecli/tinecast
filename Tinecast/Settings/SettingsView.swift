import SwiftUI

struct SettingsView: View {
    let model: SettingsModel
    @State private var history = PaneHistory()
    @State private var search = ""

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            detail
                .navigationTitle(history.current.title)
                .toolbar(removing: .title)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        ControlGroup {
                            Button("Back", systemImage: "chevron.left") { history.goBack() }
                                .disabled(!history.canGoBack)
                                .keyboardShortcut("[", modifiers: .command)
                            Button("Forward", systemImage: "chevron.right") { history.goForward() }
                                .disabled(!history.canGoForward)
                                .keyboardShortcut("]", modifiers: .command)
                        }
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let problem = model.fileProblem {
                        FileProblemBanner(problem: problem, open: model.openFile)
                    }
                }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 560, idealHeight: 640)
    }

    private var sidebar: some View {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = Pane.sidebarGroups
            .map { group in (header: group.header, panes: group.panes.filter { $0.matches(query) }) }
            .filter { !$0.panes.isEmpty }
        return List(selection: Binding(get: { history.current }, set: { if let pane = $0 { history.visit(pane) } })) {
            ForEach(groups, id: \.panes) { group in
                Section {
                    ForEach(group.panes, id: \.self) { pane in
                        Label {
                            Text(pane.title)
                        } icon: {
                            PaneTile(pane: pane, size: 20)
                        }
                    }
                } header: {
                    if let header = group.header { Text(header) }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if groups.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .searchable(text: $search, placement: .sidebar)
        .toolbar(removing: .sidebarToggle)
        .navigationSplitViewColumnWidth(220)
    }

    @ViewBuilder private var detail: some View {
        switch history.current {
        case .general: GeneralPane(model: model)
        case .permissions: PermissionsPane()
        case .applications, .systemActions: UpcomingPane(pane: history.current)
        case .commands: CommandsSettings(model: model)
        case .files: FilesPane(model: model)
        case .calculator: CalculatorPane(model: model)
        case .history: HistoryPane(model: model)
        }
    }
}

private struct FileProblemBanner: View {
    let problem: String
    let open: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Changes aren’t saved until settings.json is fixed.")
                    .fontWeight(.medium)
                Text(problem)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            Button("Open settings.json", action: open)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

private struct UpcomingPane: View {
    let pane: Pane

    var body: some View {
        Form {
            PaneHeader(pane: pane)
            Section {
                ContentUnavailableView("Coming Soon", systemImage: pane.symbol, description: Text("\(pane.title) settings will appear here."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
        .formStyle(.grouped)
    }
}
