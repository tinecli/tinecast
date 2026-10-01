import SwiftUI

struct SettingsView: View {
    let model: SettingsModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                page(GeneralSettings(model: model), height: 560)
            }
            Tab("Commands", systemImage: "terminal") {
                page(CommandsSettings(model: model), height: 500)
            }
            Tab("Aliases", systemImage: "character.cursor.ibeam") {
                page(AliasesSettings(model: model), height: 420)
            }
            Tab("Permissions", systemImage: "hand.raised") {
                page(PermissionsSettings(model: model), height: 520)
            }
        }
    }

    private func page(_ content: some View, height: CGFloat) -> some View {
        content
            .frame(width: 640, height: height)
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
}
