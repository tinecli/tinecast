import Foundation

nonisolated private let tailLength = 5

func launchInBackground(_ failureMessage: String, _ executable: String, _ arguments: [String]) {
    Task {
        do {
            guard let failure = try await failureOutput(of: executable, arguments) else { return }
            presentAlert(failureMessage, failure)
        } catch {
            presentAlert(failureMessage, error.localizedDescription)
        }
    }
}

@concurrent
func failureOutput(of executable: String, _ arguments: [String]) async throws -> String? {
    let process = Process()
    let errorPipe = Pipe()
    let (exits, exited) = AsyncStream.makeStream(of: Int32.self)
    process.executableURL = URL(filePath: executable)
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = errorPipe
    process.terminationHandler = { finished in
        exited.yield(finished.terminationStatus)
        exited.finish()
    }
    try process.run()
    let tail = try await errorPipe.fileHandleForReading.bytes.lines.reduce(into: [String]()) { lines, line in
        lines = Array((lines + [line]).suffix(tailLength))
    }
    let status = await exits.first { _ in true } ?? process.terminationStatus
    guard status != 0 else { return nil }
    return "Exited with status \(status).\n\n" + tail.joined(separator: "\n")
}
