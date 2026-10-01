import SwiftUI

struct PathList: View {
    let title: String
    let noun: String
    @Binding var paths: [String]
    @State private var selection: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selection) {
                ForEach(paths, id: \.self) { path in
                    Label((path as NSString).abbreviatingWithTildeInPath, systemImage: "folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: false))
            .frame(height: 76)
            .accessibilityLabel(title)
            ListControls(
                addLabel: "Add \(noun)…",
                removeLabel: "Remove \(noun)",
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
