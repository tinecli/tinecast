import SwiftUI

struct CalculatorPane: View {
    let model: SettingsModel
    @State private var isRefreshing = false
    @State private var refreshFailed = false

    var body: some View {
        let rates = model.exchangeRates
        Form {
            Section {
                PaneHeader(pane: .calculator)
            }
            Section("Exchange Rates") {
                LabeledContent("Source", value: "European Central Bank")
                LabeledContent("Rates From") {
                    Text(rates.map { (try? Date.ISO8601FormatStyle().year().month().day().parse($0.date))?.formatted(date: .long, time: .omitted) ?? $0.date } ?? "Not Downloaded")
                }
                LabeledContent("Last Updated") {
                    Text(rates.map { $0.fetchedAt.formatted(.relative(presentation: .named)) } ?? "Never")
                }
                HStack(spacing: 8) {
                    if refreshFailed {
                        Text("Couldn’t refresh. Check your internet connection.")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing")
                    }
                    Button("Refresh Now", action: refresh)
                        .disabled(isRefreshing)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func refresh() {
        isRefreshing = true
        refreshFailed = false
        Task {
            refreshFailed = !(await model.refreshRates())
            isRefreshing = false
        }
    }
}
