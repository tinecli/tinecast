import Foundation

public struct ExchangeRates: Codable, Equatable, Sendable {
    private static let currentWindow: TimeInterval = 7 * 24 * 60 * 60

    public let date: String
    public let fetchedAt: Date
    public let rates: [String: Double]

    public init(date: String, fetchedAt: Date, rates: [String: Double]) {
        self.date = date
        self.fetchedAt = fetchedAt
        self.rates = rates
    }

    public init?(ecbCSV csv: String, fetchedAt: Date) {
        // Splitting on commas is safe for the columns used: only the trailing title columns are quoted.
        let rows = csv.split(whereSeparator: \.isNewline).map { $0.split(separator: ",", omittingEmptySubsequences: false) }
        guard let header = rows.first,
              let currencyColumn = header.firstIndex(of: "CURRENCY"),
              let periodColumn = header.firstIndex(of: "TIME_PERIOD"),
              let valueColumn = header.firstIndex(of: "OBS_VALUE")
        else { return nil }
        let dateStyle = Date.ISO8601FormatStyle().year().month().day()
        let observations = rows.dropFirst().compactMap { row -> (code: String, period: String, date: Date, rate: Double)? in
            guard row.count > max(currencyColumn, periodColumn, valueColumn),
                  let date = try? dateStyle.parse(String(row[periodColumn])),
                  let rate = Double(row[valueColumn]), rate > 0
            else { return nil }
            return (String(row[currencyColumn]), String(row[periodColumn]), date, rate)
        }
        guard let newest = observations.max(by: { $0.date < $1.date }) else { return nil }
        let current = observations.filter { newest.date.timeIntervalSince($0.date) <= Self.currentWindow }
        self.init(
            date: newest.period,
            fetchedAt: fetchedAt,
            rates: Dictionary(current.map { ($0.code, $0.rate) }, uniquingKeysWith: { first, _ in first }).merging(["EUR": 1]) { current, _ in current }
        )
    }
}
