import Foundation
import os
import TineCastKit

private let logger = Logger(subsystem: "dev.gustaf.tinecast", category: "rates")

final class RatesProvider {
    private static let source = URL(string: "https://data-api.ecb.europa.eu/service/data/EXR/D..EUR.SP00.A?lastNObservations=1&format=csvdata")!
    private static let retryDelay: TimeInterval = 60 * 60
    private static let timeout: TimeInterval = 10

    private let file: JSONFile<ExchangeRates>
    private let onUpdate: (ExchangeRates) -> Void
    private var rates: ExchangeRates?
    private var download: Task<Void, Never>?
    private var failedAt: Date?

    init(file: JSONFile<ExchangeRates>, onUpdate: @escaping (ExchangeRates) -> Void) {
        self.file = file
        self.onUpdate = onUpdate
        rates = file.load()
        if let rates { onUpdate(rates) }
    }

    func refreshIfStale() {
        guard download == nil else { return }
        if let rates, !rates.isStale(at: .now) { return }
        if let failedAt, Date.now.timeIntervalSince(failedAt) < Self.retryDelay { return }
        startDownload()
    }

    func refreshNow() async -> Bool {
        if download == nil { startDownload() }
        await download?.value
        return failedAt == nil
    }

    private func startDownload() {
        download = Task { [weak self] in
            await self?.fetch()
            self?.download = nil
        }
    }

    private func fetch() async {
        let request = URLRequest(url: Self.source, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.timeout)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let fresh = ExchangeRates(ecbCSV: String(decoding: data, as: UTF8.self), fetchedAt: .now)
            else { throw URLError(.cannotParseResponse) }
            rates = fresh
            failedAt = nil
            file.save(fresh)
            onUpdate(fresh)
        } catch {
            failedAt = .now
            logger.error("Exchange rates couldn't be fetched, keeping cached ones: \(error.localizedDescription, privacy: .public)")
        }
    }
}
