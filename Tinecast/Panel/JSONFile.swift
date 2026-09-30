import Foundation
import os

private let logger = Logger(subsystem: "dev.gustaf.tinecast", category: "storage")

struct JSONFile<Value: Codable> {
    let url: URL

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            logger.error("\(url.lastPathComponent, privacy: .public) is corrupt and is being moved aside: \(String(describing: error), privacy: .public)")
        }
        let corruptURL = url.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: corruptURL)
        do {
            try FileManager.default.moveItem(at: url, to: corruptURL)
        } catch {
            logger.fault("\(url.lastPathComponent, privacy: .public) couldn't be moved aside: \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }

    func save(_ value: Value) {
        do {
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            logger.error("\(url.lastPathComponent, privacy: .public) couldn't be saved: \(error.localizedDescription, privacy: .public)")
        }
    }
}
