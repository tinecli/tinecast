import Foundation

nonisolated final class MainThreadWatchdog: @unchecked Sendable {
    static let shared = UserDefaults.standard.bool(forKey: "TinecastDiagnostics")
        ? MainThreadWatchdog(log: URL.applicationSupportDirectory.appending(path: "dev.gustaf.tinecast/diagnostics.log"))
        : nil
    private static let interval = 0.25
    private static let threshold = 0.3

    private let log: LogFile
    private let queue = DispatchQueue(label: "dev.gustaf.tinecast.watchdog")
    private var timer: (any DispatchSourceTimer)?
    private var lastSample = Date.distantPast

    init(log: URL) {
        self.log = LogFile(url: log)
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.interval, repeating: Self.interval)
        timer.setEventHandler { [weak self] in self?.ping() }
        timer.resume()
        self.timer = timer
    }

    func note(_ event: String) {
        let line = "\(Date.now.ISO8601Format(.init(includingFractionalSeconds: true))) \(event)\n"
        queue.async { [log] in log.append(line) }
    }

    private func ping() {
        let sent = Date.now
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { semaphore.signal() }
        guard semaphore.wait(timeout: .now() + Self.threshold) == .timedOut else { return }
        sampleMainThread()
        semaphore.wait()
        log.append("\(sent.ISO8601Format()) main thread stalled for \(Int(Date.now.timeIntervalSince(sent) * 1000)) ms\n")
    }

    private func sampleMainThread() {
        guard Date.now.timeIntervalSince(lastSample) > 60 else { return }
        lastSample = .now
        FileManager.default.createFile(atPath: log.url.deletingLastPathComponent().appending(path: "stall-now").path(percentEncoded: false), contents: nil)
    }
}
