import AppKit
import Observation
import TineCastKit

@Observable
final class AppUpdater {
    enum Status: Equatable {
        case idle, checking, downloading
        case upToDate(String)
        case ready(String)
        case blocked(String)
        case failed(String)
    }

    enum Trigger {
        case scheduled, manual
    }

    private enum AfterSwap: String {
        case open, quiet
    }

    nonisolated static let releasesURL = URL(string: "https://github.com/tinecli/tinecast/releases/latest")!
    nonisolated static let teamRequirement = "=anchor apple generic and certificate leaf[subject.OU] = \"82K3YC8HVF\""
    nonisolated static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    nonisolated private static let stagingPrefix = ".tinecast-update-"

    private(set) var status = Status.idle
    private(set) var staged: (version: String, app: URL)?
    @ObservationIgnored private var newerVersion: String?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored private var swapping = false

    var isBusy: Bool { status == .checking || status == .downloading }

    nonisolated static var isSelfUpdatable: Bool {
        #if DEBUG
        false
        #else
        Bundle.main.bundleURL.pathExtension == "app"
        #endif
    }

    nonisolated static var installDir: URL { Bundle.main.bundleURL.deletingLastPathComponent() }

    func start() {
        guard Self.isSelfUpdatable else {
            status = .blocked("This build doesn’t update itself.")
            return
        }
        Self.clearStaging()
        check()
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func check(_ trigger: Trigger = .scheduled) {
        guard Self.isSelfUpdatable else {
            status = .blocked("This build doesn’t update itself.")
            return
        }
        if let staged {
            status = .ready(staged.version)
            return
        }
        guard !isBusy else { return }
        let previous = status
        status = .checking
        Task { await runCheck(trigger, previous: previous) }
    }

    private func runCheck(_ trigger: Trigger, previous: Status) async {
        guard let latest = await Self.latestVersion() else {
            status = trigger == .manual ? .failed("Couldn’t reach github.com.") : newerVersion == nil ? .idle : previous
            return
        }
        guard isNewerVersion(latest, than: Self.currentVersion) else {
            newerVersion = nil
            status = .upToDate(Self.currentVersion)
            return
        }
        newerVersion = latest
        guard FileManager.default.isWritableFile(atPath: Self.installDir.path) else {
            status = .blocked("TineCast can’t update itself in \(Self.installDir.path). Download it instead.")
            if trigger == .manual { NSWorkspace.shared.open(Self.releasesURL) }
            return
        }
        status = .downloading
        do {
            staged = (latest, try await Self.downloadVerified(version: latest))
            status = .ready(latest)
        } catch {
            Self.clearStaging()
            status = .failed(error.localizedDescription)
            if trigger == .manual { NSWorkspace.shared.open(Self.releasesURL) }
        }
    }

    func installAndRelaunch() {
        if let reason = spawnSwap(then: .open) {
            if !isBusy { status = .blocked(reason) }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }

    func installOnQuit() {
        guard staged != nil else { return }
        _ = spawnSwap(then: .quiet)
    }

    private func spawnSwap(then after: AfterSwap) -> String? {
        guard !swapping else { return nil }
        guard let staged else { return "No update is downloaded." }
        let installed = Self.bundleVersion(of: Bundle.main.bundleURL)
        if let installed, !isNewerVersion(staged.version, than: installed) {
            self.staged = nil
            Self.clearStaging()
            return "\(installed) is already installed."
        }
        guard FileManager.default.isWritableFile(atPath: Self.installDir.path) else {
            return "\(Self.installDir.path) isn’t writable."
        }
        let script = URL.temporaryDirectory.appending(path: "tinecast-update-\(UUID().uuidString).sh")
        guard (try? updateSwapScript.write(to: script, atomically: true, encoding: .utf8)) != nil else {
            return "Couldn’t prepare the update."
        }
        let helper = Process()
        helper.executableURL = URL(filePath: "/bin/sh")
        helper.arguments = [script.path, "\(getpid())", staged.app.path, Bundle.main.bundleURL.path, after.rawValue, installed ?? ""]
        guard (try? helper.run()) != nil else { return "Couldn’t start the update." }
        swapping = true
        return nil
    }

    private static func latestVersion() async -> String? {
        var request = URLRequest(url: releasesURL)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await URLSession.shared.data(for: request, delegate: RedirectBlocker()),
              let location = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Location")
        else { return nil }
        return releaseVersion(fromLocation: location)
    }

    nonisolated private static func dmgURL(version: String) -> URL {
        URL(string: "https://github.com/tinecli/tinecast/releases/download/v\(version)/tinecast-\(version).dmg")!
    }

    nonisolated private static func clearStaging() {
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: installDir.path)) ?? []
        for entry in leftovers where entry.hasPrefix(stagingPrefix) {
            try? FileManager.default.removeItem(at: installDir.appending(path: entry))
        }
    }

    @concurrent nonisolated private static func downloadVerified(version: String) async throws -> URL {
        let fileManager = FileManager.default
        let root = installDir.appending(path: "\(stagingPrefix)\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        var keep = false
        defer { if !keep { try? fileManager.removeItem(at: root) } }

        let (download, response) = try await URLSession.shared.download(from: dmgURL(version: version))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateFailure("The update download failed.") }
        let dmg = root.appending(path: "tinecast.dmg")
        try fileManager.moveItem(at: download, to: dmg)

        let mount = root.appending(path: "mnt")
        guard run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mount.path]) else {
            throw UpdateFailure("Couldn’t open the downloaded disk image.")
        }
        defer { _ = run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }

        let source = mount.appending(path: "TineCast.app")
        guard bundleVersion(of: source) == version else { throw UpdateFailure("The downloaded app isn’t version \(version).") }
        guard isTrusted(source) else { throw UpdateFailure("The downloaded app failed signature checks.") }
        let app = root.appending(path: "TineCast.app")
        guard run("/usr/bin/ditto", [source.path, app.path]), isTrusted(app) else {
            throw UpdateFailure("The downloaded app failed signature checks.")
        }
        keep = true
        return app
    }

    // spctl is avoided on purpose: it false-negatives on stapled builds.
    nonisolated private static func isTrusted(_ app: URL) -> Bool {
        run("/usr/bin/codesign", ["--verify", "--strict", "-R", teamRequirement, app.path])
    }

    nonisolated private static func bundleVersion(of app: URL) -> String? {
        guard let data = FileManager.default.contents(atPath: app.appending(path: "Contents/Info.plist").path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleShortVersionString"] as? String
    }

    nonisolated private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

private struct UpdateFailure: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
        errorDescription = message
    }
}

// URLSession follows redirects by default, and the release tag lives only in the 302's Location header.
private nonisolated final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
