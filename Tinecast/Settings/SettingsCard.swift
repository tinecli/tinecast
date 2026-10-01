import AppKit
import SwiftUI

struct SettingsCard<Content: View>: View {
    private static var fill: Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(srgbRed: 37 / 255, green: 37 / 255, blue: 37 / 255, alpha: 1) : NSColor(srgbRed: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1) })
    }

    private static var divider: Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(srgbRed: 47 / 255, green: 47 / 255, blue: 47 / 255, alpha: 1) : NSColor(srgbRed: 235 / 255, green: 235 / 255, blue: 235 / 255, alpha: 1) })
    }

    var title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.top, 20)
                    .padding(.horizontal, 10)
                    .accessibilityAddTraits(.isHeader)
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            Rectangle()
                                .fill(Self.divider)
                                .frame(height: 1)
                        }
                        row
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 10)
            .background(Self.fill, in: .rect(cornerRadius: 12, style: .continuous))
        }
    }
}
