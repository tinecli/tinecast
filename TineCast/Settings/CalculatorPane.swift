import SwiftUI
import TineCastKit

struct CalculatorPane: View {
    private static let precisions: [(title: String, precision: Config.Calculator.Precision)] =
        [("Automatic", .automatic)] + (0...10).map { ("\($0)", .places($0)) } + [("Full Precision", .full)]

    @Bindable var model: SettingsModel
    @State private var isRefreshing = false
    @State private var refreshFailed = false

    var body: some View {
        let rates = model.exchangeRates
        Form {
            Section {
                PaneHeader(pane: .calculator)
            }
            Section("Units") {
                Toggle(isOn: $model.config.calculator.autoConvertUnits) {
                    Text(SettingRow.autoConvertUnits.label)
                    Text("Shows 6 inch in centimeters without typing “in cm”.")
                }
                .modifier(SearchAnchor(id: SettingRow.autoConvertUnits.rawValue))
                Picker(SettingRow.inchFractions.label, selection: $model.config.calculator.inchFraction) {
                    ForEach(Config.Calculator.inchFractions, id: \.self) { denominator in
                        Text("1/\(denominator)").tag(denominator)
                    }
                }
                .modifier(SearchAnchor(id: SettingRow.inchFractions.rawValue))
                Picker(selection: $model.config.calculator.precision) {
                    ForEach(Self.precisions, id: \.precision) { option in
                        Text(option.title).tag(option.precision)
                    }
                    if !Self.precisions.contains(where: { $0.precision == model.config.calculator.precision }),
                       case .places(let places) = model.config.calculator.precision {
                        Text("\(places)").tag(model.config.calculator.precision)
                    }
                } label: {
                    Text(SettingRow.decimalPlaces.label)
                    Text("Currency always shows two.")
                }
                .modifier(SearchAnchor(id: SettingRow.decimalPlaces.rawValue))
            }
            Section("Exchange Rates") {
                LabeledContent(SettingRow.rateSource.label, value: "European Central Bank")
                    .modifier(SearchAnchor(id: SettingRow.rateSource.rawValue))
                LabeledContent(SettingRow.ratesFrom.label) {
                    Text(rates.map { (try? Date.ISO8601FormatStyle().year().month().day().parse($0.date))?.formatted(date: .long, time: .omitted) ?? $0.date } ?? "Not Downloaded")
                }
                .modifier(SearchAnchor(id: SettingRow.ratesFrom.rawValue))
                LabeledContent(SettingRow.lastUpdated.label) {
                    Text(rates.map { $0.fetchedAt.formatted(.relative(presentation: .named)) } ?? "Never")
                }
                .modifier(SearchAnchor(id: SettingRow.lastUpdated.rawValue))
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
                    Button(SettingRow.refreshRates.label, action: refresh)
                        .disabled(isRefreshing)
                }
                .modifier(SearchAnchor(id: SettingRow.refreshRates.rawValue))
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
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
