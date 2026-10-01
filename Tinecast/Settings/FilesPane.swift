import SwiftUI

struct FilesPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                PaneHeader(pane: .files)
            }
            Section("Search In") {
                FolderList(title: "Search In", paths: $model.config.fileSearch.folders)
            }
            Section("Exclude") {
                FolderList(title: "Exclude", paths: $model.config.fileSearch.exclusions)
            }
        }
        .formStyle(.grouped)
    }
}
