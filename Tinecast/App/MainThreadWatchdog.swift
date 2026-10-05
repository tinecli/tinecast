import Foundation

nonisolated final class MainThreadWatchdog: @unchecked Sendable {
    static let shared = MainThreadWatchdog(log: URL.applicationSupportDirectory.appending(path: "dev.gustaf.tinecast/diagnostics.log"))
    private static let interval = 0.25
    private static let threshold = 0.3

    private let log: URL
    private let queue = DispatchQueue(label: "dev.gustaf.tinecast.watchdog")
    private var timer: (any DispatchSourceTimer)?
    private var lastSample = Date.distantPast

    init(log: URL) {
        self.log = log
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.interval, repeating: Self.interval)
        timer.setEventHandler { [weak self] in self?.ping() }
        timer.resume()
        self.timer = timer
    }

    func note(_ event: String) {
        queue.async { [log] in Self.append("\(Date.now.ISO8601Format()) \(event)\n", to: log) }
    }

    private func ping() {
        let sent = Date.now
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { semaphore.signal() }
        guard semaphore.wait(timeout: .now() + Self.threshold) == .timedOut else { return }
        sampleMainThread()
        semaphore.wait()
        Self.append("\(sent.ISO8601Format()) main thread stalled for \(Int(Date.now.timeIntervalSince(sent) * 1000)) ms\n", to: log)
    }

    private func sampleMainThread() {
        guard Date.now.timeIntervalSince(lastSample) > 60 else { return }
        lastSample = .now
        let output = log.deletingLastPathComponent().appending(path: "stall-\(Date.now.ISO8601Format()).txt")
        let sample = Process()
        sample.executableURL = URL(filePath: "/usr/bin/sample")
        sample.arguments = [String(ProcessInfo.processInfo.processIdentifier), "2", "-mayDie", "-file", output.path(percentEncoded: false)]
        try? sample.run()
    }

    private static func append(_ line: String, to url: URL) {
        guard let handle = try? FileHandle(forWritingTo: url) else {
            try? Data(line.utf8).write(to: url)
            return
        }
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    }
}
