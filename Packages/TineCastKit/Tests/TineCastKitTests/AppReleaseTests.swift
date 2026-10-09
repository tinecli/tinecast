import Foundation
import Testing
import TineCastKit

@Test func releaseVersionReadsTheTagAfterTheLastSlash() {
    #expect(releaseVersion(fromLocation: "https://github.com/tinecli/tinecast/releases/tag/v0.1.29") == "0.1.29")
    #expect(releaseVersion(fromLocation: "https://github.com/tinecli/tinecast/releases/tag/1.2.3") == "1.2.3")
}

@Test func releaseVersionRejectsAnythingButPlainDottedNumbers() {
    #expect(releaseVersion(fromLocation: "https://github.com/tinecli/tinecast/releases/tag/latest") == nil)
    #expect(releaseVersion(fromLocation: "https://github.com/tinecli/tinecast/releases/tag/v") == nil)
    #expect(releaseVersion(fromLocation: "https://github.com/x/y/releases/tag/v1.٢.3") == nil)
}

@Test func isNewerVersionComparesComponentsNumerically() {
    #expect(isNewerVersion("0.2.0", than: "0.1.9"))
    #expect(!isNewerVersion("0.1.9", than: "0.2.0"))
    #expect(!isNewerVersion("0.1.9", than: "0.1.9"))
    #expect(isNewerVersion("0.1.10", than: "0.1.9"))
}

@Test func isNewerVersionTreatsAMissingTrailingComponentAsZero() {
    #expect(!isNewerVersion("1.2", than: "1.2.0"))
    #expect(isNewerVersion("1.2.1", than: "1.2"))
}

@Test func swapScriptInstallsTheStagedAppWhenTheTargetIsUntouched() throws {
    let bundles = try SwapFixture(target: "0.1.36", staged: "0.1.37")

    #expect(try bundles.run(expecting: "0.1.36") == 0)
    #expect(try bundles.targetVersion() == "0.1.37")
    #expect(!FileManager.default.fileExists(atPath: bundles.staged.path))
}

@Test func swapScriptKeepsAnInstallThatLandedWhileItWaited() throws {
    let bundles = try SwapFixture(target: "0.1.36", staged: "0.1.37")
    try SwapFixture.write(version: "0.1.38", to: bundles.target)

    #expect(try bundles.run(expecting: "0.1.36") != 0)
    #expect(try bundles.targetVersion() == "0.1.38")
}

@Test func swapScriptRepairsATargetWithNoReadableVersion() throws {
    let bundles = try SwapFixture(target: "0.1.36", staged: "0.1.37")
    try FileManager.default.removeItem(at: bundles.target.appending(path: "Contents/Info.plist"))

    #expect(try bundles.run(expecting: "") == 0)
    #expect(try bundles.targetVersion() == "0.1.37")
}

private struct SwapFixture {
    let root = URL.temporaryDirectory.appending(path: "tinecast-swap-\(UUID().uuidString)")
    let target: URL
    let staged: URL

    init(target targetVersion: String, staged stagedVersion: String) throws {
        target = root.appending(path: "Applications/tinecast.app")
        staged = root.appending(path: "staging/tinecast.app")
        try Self.write(version: targetVersion, to: target)
        try Self.write(version: stagedVersion, to: staged)
    }

    static func write(version: String, to app: URL) throws {
        let contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleShortVersionString": version], format: .xml, options: 0)
        try plist.write(to: contents.appending(path: "Info.plist"))
    }

    func targetVersion() throws -> String? {
        let data = try Data(contentsOf: target.appending(path: "Contents/Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        return plist?["CFBundleShortVersionString"]
    }

    func run(expecting expected: String) throws -> Int32 {
        let script = root.appending(path: "swap.sh")
        try updateSwapScript.write(to: script, atomically: true, encoding: .utf8)
        let exited = Process()
        exited.executableURL = URL(filePath: "/usr/bin/true")
        try exited.run()
        exited.waitUntilExit()
        let helper = Process()
        helper.executableURL = URL(filePath: "/bin/sh")
        helper.arguments = [script.path, "\(exited.processIdentifier)", staged.path, target.path, "quiet", expected]
        try helper.run()
        helper.waitUntilExit()
        return helper.terminationStatus
    }
}
