import SwiftUI

struct FolderList: View {
    let title: String
    @Binding var paths: [String]
    @State private var selection: String?

    var body: some View {
        let names = paths.map { FileManager.default.displayName(atPath: ($0 as NSString).expandingTildeInPath) }
        if paths.isEmpty {
            Text("No folders")
                .foregroundStyle(.secondary)
        }
        ForEach(Array(zip(paths, names)), id: \.0) { path, name in
            let isSelected = path == selection
            HStack(spacing: 8) {
                ItemIcon(icon: .file(URL(filePath: (path as NSString).expandingTildeInPath)))
                    .frame(width: 20, height: 20)
                Text(name)
                if names.filter({ $0 == name }).count > 1 {
                    Text(path)
                        .foregroundStyle(.secondary)
                        .truncationMode(.middle)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
                        .padding(.horizontal, -6)
                        .padding(.vertical, -6)
                }
            }
            .onTapGesture { selection = isSelected ? nil : path }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { selection = path }
        }
        HStack(spacing: 2) {
            Button("Add Folder…", systemImage: "plus", action: add)
            Button("Remove Folder", systemImage: "minus") {
                paths.removeAll { $0 == selection }
                selection = nil
            }
            .disabled(selection == nil)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
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
