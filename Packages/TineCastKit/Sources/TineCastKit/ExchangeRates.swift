import Foundation

public struct ExchangeRates: Codable, Equatable, Sendable {
    private static let currentWindow: TimeInterval = 7 * 24 * 60 * 60
    private static let retryInterval: TimeInterval = 60 * 60

    public let date: String
    public let fetchedAt: Date
    public let rates: [String: Double]

    public init(date: String, fetchedAt: Date, rates: [String: Double]) {
        self.date = date
        self.fetchedAt = fetchedAt
        self.rates = rates
    }

    public func isStale(at now: Date) -> Bool {
        guard now.timeIntervalSince(fetchedAt) >= Self.retryInterval else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        guard let rateDay = try? Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day().parse(date),
              let publishedToday = calendar.date(bySettingHour: 16, minute: 15, second: 0, of: now)
        else { return true }
        let latestPublication = (0...3).lazy
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: publishedToday) }
            .first { $0 <= now && !calendar.isDateInWeekend($0) }
        return latestPublication.map { calendar.startOfDay(for: $0) > rateDay } ?? true
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
