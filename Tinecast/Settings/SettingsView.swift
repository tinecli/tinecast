import AppKit
import SwiftUI

struct SettingsView: View {
    let model: SettingsModel
    @State private var history = PaneHistory(start: initialPane)
    @State private var search = initialSearch
    @State private var sections: [SearchSection] = []
    @State private var selectedResult: SearchResult?
    @State private var reveal: SearchReveal?

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } detail: {
            ScrollViewReader { proxy in
                detail
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .environment(\.searchReveal, reveal)
                    .task(id: reveal) { await scroll(proxy) }
            }
            .navigationTitle(history.current.title)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Back", systemImage: "chevron.left") { history.goBack() }
                        .disabled(!history.canGoBack)
                        .keyboardShortcut("[", modifiers: .command)
                    Button("Forward", systemImage: "chevron.right") { history.goForward() }
                        .disabled(!history.canGoForward)
                        .keyboardShortcut("]", modifiers: .command)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if let problem = model.fileProblem {
                    FileProblemBanner(problem: problem, open: model.openFile)
                }
            }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 560, idealHeight: 640)
        .background(TitlebarSeparatorRemover())
    }

    private static var initialPane: Pane {
        #if DEBUG
        if let snapshot = SettingsSnapshot.requested { return snapshot.pane }
        #endif
        return .general
    }

    private static var initialSearch: String {
        #if DEBUG
        if let search = SettingsSnapshot.requested?.search { return search }
        #endif
        return ""
    }

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sidebar: some View {
        let groups = Pane.sidebarGroups
            .map { group in (header: group.header, panes: group.panes.filter { $0.matches(query) }) }
            .filter { !$0.panes.isEmpty }
        return List(selection: selection) {
            if query.isEmpty {
                ForEach(groups, id: \.panes) { group in
                    Section {
                        paneRows(group.panes)
                    } header: {
                        if let header = group.header { Text(header) }
                    }
                }
            } else {
                Section {
                    paneRows(groups.flatMap(\.panes))
                }
                ForEach(sections) { section in
                    Section {
                        ForEach(section.results) { result in
                            SearchResultRow(result: result)
                                .tag(SidebarItem.result(result))
                        }
                    } header: {
                        Label {
                            Text(section.pane.title)
                        } icon: {
                            PaneTile(pane: section.pane, size: 16)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if groups.isEmpty && sections.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .searchable(text: $search, placement: .sidebar)
        .onChange(of: search, initial: true, updateSections)
        .onChange(of: model.applications, updateSections)
        .onChange(of: model.commandItems, updateSections)
        .onChange(of: model.config.aliases, updateSections)
        #if DEBUG
        .task {
            guard let index = SettingsSnapshot.requested?.reveal else { return }
            try? await Task.sleep(for: .seconds(0.9))
            if let result = sections.flatMap(\.results).dropFirst(index).first { selection.wrappedValue = .result(result) }
        }
        #endif
        .toolbar(removing: .sidebarToggle)
        .navigationSplitViewColumnWidth(220)
    }

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: {
                guard let selectedResult, selectedResult.pane == history.current else { return .pane(history.current) }
                return .result(selectedResult)
            },
            set: { item in
                if case .pane(let pane) = item {
                    selectedResult = nil
                    history.visit(pane)
                }
                if case .result(let result) = item {
                    selectedResult = result
                    history.visit(result.pane)
                    reveal = SearchReveal(result)
                }
            }
        )
    }

    private func paneRows(_ panes: [Pane]) -> some View {
        ForEach(panes, id: \.self) { pane in
            Label {
                Text(pane.title)
            } icon: {
                PaneTile(pane: pane, size: 20)
            }
            .tag(SidebarItem.pane(pane))
        }
    }

    private func updateSections() {
        sections = model.searchSections(matching: query)
        if query.isEmpty { selectedResult = nil }
    }

    private func scroll(_ proxy: ScrollViewProxy) async {
        guard let anchor = reveal?.anchor else { return }
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation { proxy.scrollTo(anchor, anchor: .center) }
        try? await Task.sleep(for: .seconds(2))
        reveal = nil
    }

    @ViewBuilder private var detail: some View {
        switch history.current {
        case .general: GeneralPane(model: model)
        case .permissions: PermissionsPane()
        case .applications: ApplicationsSettings(model: model)
        case .systemActions: SystemActionsSettings(model: model)
        case .commands: CommandsSettings(model: model)
        case .files: FilesPane(model: model)
        case .calculator: CalculatorPane(model: model)
        case .history: HistoryPane(model: model)
        }
    }
}

private enum SidebarItem: Hashable {
    case pane(Pane)
    case result(SearchResult)
}

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        Label {
            Text(result.title)
                .foregroundStyle(result.anchor == nil ? .secondary : .primary)
        } icon: {
            if case .symbol(let name) = result.icon {
                PaneTile(symbol: name, color: result.pane.color, size: 20)
                    .symbolVariant(.fill)
            } else if let icon = result.icon {
                ItemIcon(icon: icon)
                    .frame(width: 20, height: 20)
            } else {
                Color.clear
                    .frame(width: 20, height: 20)
            }
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

private struct TitlebarSeparatorRemover: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.titlebarSeparatorStyle = .none }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
