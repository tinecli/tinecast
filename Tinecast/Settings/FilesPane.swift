import SwiftUI

struct FilesPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsCard {
                    PaneHeader(pane: .files)
                }
                SettingsCard(title: "Search In") {
                    FolderList(title: "Search In", paths: $model.config.fileSearch.folders)
                }
                SettingsCard(title: "Exclude") {
                    FolderList(title: "Exclude", paths: $model.config.fileSearch.exclusions)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
