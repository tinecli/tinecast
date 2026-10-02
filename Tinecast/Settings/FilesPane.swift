import SwiftUI

struct FilesPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsCard {
                    PaneHeader(pane: .files)
                }
                SettingsCard(title: SettingRow.searchIn.label) {
                    FolderList(title: SettingRow.searchIn.label, paths: $model.config.fileSearch.folders)
                }
                .modifier(SearchAnchor(id: SettingRow.searchIn.rawValue))
                SettingsCard(title: SettingRow.exclude.label) {
                    FolderList(title: SettingRow.exclude.label, paths: $model.config.fileSearch.exclusions)
                }
                .modifier(SearchAnchor(id: SettingRow.exclude.rawValue))
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
