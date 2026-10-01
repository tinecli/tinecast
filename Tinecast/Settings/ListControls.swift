import SwiftUI

struct ListControls: View {
    let addLabel: String
    let removeLabel: String
    let add: () -> Void
    let remove: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button(action: add) {
                Image(systemName: "plus")
                    .frame(width: 24, height: 22)
                    .contentShape(.rect)
            }
            .accessibilityLabel(addLabel)
            .help(addLabel)
            Divider()
                .frame(height: 14)
            Button {
                remove?()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 22)
                    .contentShape(.rect)
            }
            .disabled(remove == nil)
            .accessibilityLabel(removeLabel)
            .help(removeLabel)
            Spacer()
        }
        .buttonStyle(.borderless)
    }
}
