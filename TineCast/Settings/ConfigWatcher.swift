import Foundation
import os
import TineCastKit

final class ConfigWatcher {
    private let url: URL
    private let onReload: (Config) -> Void
    private let onInvalid: (String) -> Void
    private var lastData: Data?
    private var directorySource: (any DispatchSourceFileSystemObject)?
    private var fileSource: (any DispatchSourceFileSystemObject)?
    private var pendingReload: Task<Void, Never>?

    init(url: URL, onReload: @escaping (Config) -> Void, onInvalid: @escaping (String) -> Void) {
        self.url = url
        self.onReload = onReload
        self.onInvalid = onInvalid
        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            do {
                try Config().json().write(to: url, options: .atomic)
            } catch {
                Logger(subsystem: "dev.gustaf.tinecast", category: "settings").error("Default settings couldn't be written: \(error.localizedDescription, privacy: .public)")
            }
        }
        // Atomic saves replace the file and only show up on the folder; in-place saves only show up on the file.
        directorySource = source(watching: url.deletingLastPathComponent(), events: .write)
        fileSource = source(watching: url, events: [.write, .extend, .delete, .rename])
        reload()
    }

    isolated deinit {
        directorySource?.cancel()
        fileSource?.cancel()
    }

    private func source(watching url: URL, events: DispatchSource.FileSystemEvent) -> (any DispatchSourceFileSystemObject)? {
        let descriptor = open(url.path(percentEncoded: false), O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleReload() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }

    private func scheduleReload() {
        pendingReload?.cancel()
        pendingReload = Task { [weak self] in
            guard (try? await Task.sleep(for: .milliseconds(100))) != nil, let self else { return }
            fileSource?.cancel()
            fileSource = source(watching: url, events: [.write, .extend, .delete, .rename])
            reload()
        }
    }

    private func reload() {
        guard let data = try? Data(contentsOf: url), data != lastData else { return }
        lastData = data
        do {
            onReload(try Config(json: data))
        } catch {
            onInvalid(error.errorDescription ?? "settings.json couldn't be read.")
        }
    }
}
