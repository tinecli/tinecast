import SwiftUI

struct FilterBar: View {
    let prompt: String
    @Binding var text: String
    @Binding var scope: ItemScope

    var body: some View {
        HStack(spacing: 12) {
            SearchField(prompt: prompt, text: $text)
            Picker("Show", selection: $scope) {
                ForEach(ItemScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }
}

struct SearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
            if !text.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear Search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.fill.tertiary, in: .capsule)
    }
}
