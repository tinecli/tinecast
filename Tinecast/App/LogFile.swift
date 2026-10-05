import Foundation

nonisolated struct LogFile: Sendable {
    private static let limit: UInt64 = 256 * 1024

    let url: URL

    func append(_ line: String) {
        let data = Data(line.utf8)
        guard let handle = try? FileHandle(forWritingTo: url) else {
            try? data.write(to: url)
            return
        }
        guard handle.seekToEndOfFile() > Self.limit else {
            handle.write(data)
            try? handle.close()
            return
        }
        try? handle.close()
        let backup = url.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: url, to: backup)
        try? data.write(to: url)
    }
}
