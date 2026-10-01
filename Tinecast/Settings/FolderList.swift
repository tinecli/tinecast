import SwiftUI

struct FolderList: View {
    let title: String
    @Binding var paths: [String]
    @State private var selection: Set<String> = []

    var body: some View {
        let names = paths.map { FileManager.default.displayName(atPath: ($0 as NSString).expandingTildeInPath) }
        VStack(alignment: .leading, spacing: 0) {
            List(Array(zip(paths, names)), id: \.0, selection: $selection) { path, name in
                Label {
                    HStack(spacing: 6) {
                        Text(name)
                        if names.filter({ $0 == name }).count > 1 {
                            Text(path)
                                .foregroundStyle(.secondary)
                                .truncationMode(.middle)
                        }
                    }
                    .lineLimit(1)
                } icon: {
                    ItemIcon(icon: .file(URL(filePath: (path as NSString).expandingTildeInPath)))
                        .frame(width: 16, height: 16)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: false))
            .frame(height: 96)
            .overlay {
                if paths.isEmpty {
                    Text("No Folders")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(title)
            ListControls(
                addLabel: "Add Folder…",
                removeLabel: "Remove Folder",
                add: add,
                remove: selection.isEmpty ? nil : { paths.removeAll { selection.contains($0) }; selection = [] }
            )
        }
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        let chosen = panel.urls.map { ($0.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath }
        paths += chosen.filter { !paths.contains($0) }
    }
}
