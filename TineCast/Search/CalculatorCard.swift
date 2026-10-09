import SwiftUI
import TineCastKit

struct CalculatorCard: View {
    static let height = 3 * ResultsList.rowHeight

    let calculation: Calculation
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let fill = (colorScheme == .dark ? Color.white : .black).opacity(contrast == .increased ? 0.22 : 0.11)
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                column(calculation.input, fill: fill)
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                column(calculation.result, fill: fill)
            }
            if let note = calculation.note {
                Text(note)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, ResultRow.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(fill.opacity(isSelected ? 1 : 0), in: .rect(corners: .concentric(minimum: 16)))
        .contentShape(.rect)
    }

    private func column(_ side: Calculation.Side, fill: Color) -> some View {
        VStack(spacing: 6) {
            Text(side.text)
                .font(.title.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(side.name)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(fill, in: .rect(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity)
    }
}
