import SwiftUI

struct MoreMenuItem {
    let title: String
    let shortcut: String
    let action: () -> Void
}

struct MoreMenu: View {
    private static let cornerRadius = LauncherView.cornerRadius - ActionBar.edgeInset
    private static let padding: CGFloat = 5
    private static let rowHeight: CGFloat = 24

    let items: [MoreMenuItem]
    let isOpen: Bool
    @Binding var highlighted: Int?
    let toggle: () -> Void
    let activate: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let fill = (colorScheme == .dark ? Color.white : .black).opacity(contrast == .increased ? 0.22 : 0.11)
        ZStack(alignment: .bottomLeading) {
            if isOpen {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture(perform: toggle)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 0) {
                if isOpen {
                    VStack(spacing: 0) {
                        ForEach(items.indices, id: \.self) { index in
                            if index > 0 {
                                Divider()
                                    .padding(.horizontal, Self.padding + 4)
                                    .padding(.vertical, Self.padding)
                            }
                            row(at: index, fill: fill)
                        }
                    }
                    .padding(Self.padding)
                    .transition(.opacity)
                }
                Button(action: toggle) {
                    Image(systemName: "ellipsis")
                        .frame(width: ActionBar.controlHeight, height: ActionBar.controlHeight)
                        .contentShape(.circle)
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .foregroundStyle(.secondary)
                .accessibilityLabel("More")
                .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            }
            .fixedSize()
            .background(fill, in: .rect(cornerRadius: Self.cornerRadius))
            .clipShape(.rect(cornerRadius: Self.cornerRadius))
            .padding(ActionBar.edgeInset)
        }
    }

    private func row(at index: Int, fill: Color) -> some View {
        let item = items[index]
        return Button { activate(index) } label: {
            HStack(spacing: 0) {
                Text(item.title)
                Spacer(minLength: 24)
                Text(item.shortcut)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Self.padding + 4)
            .frame(maxWidth: .infinity)
            .frame(height: Self.rowHeight)
            .background(fill.opacity(highlighted == index ? 1 : 0), in: .rect(cornerRadius: Self.cornerRadius - Self.padding))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(item.title)
        .onHover { hovering in
            if hovering {
                highlighted = index
            } else if highlighted == index {
                highlighted = nil
            }
        }
    }
}
