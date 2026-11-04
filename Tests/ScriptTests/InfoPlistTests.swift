import Foundation
import Testing
import ChronobarCore

/// Runs scripts/info-plist.sh, which writes the Info.plist scripts/bundle-app.sh puts in the bundle, and
/// reads what it writes the way the app does at launch, through `BuildVariant`.
@Suite struct InfoPlistTests {
    static let script = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("scripts/info-plist.sh")

    private func infoPlist(_ arguments: [String] = []) throws -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [Self.script.path] + arguments
        process.environment = ["VERSION": "1.2.3", "PATH": "/usr/bin:/bin"]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test func theEverydayCopyKeepsItsBundleIDNameAndDataFolder() throws {
        let info = try infoPlist()
        #expect(info["CFBundleIdentifier"] as? String == "io.github.nhall.chronobar")
        #expect(info["CFBundleName"] as? String == "Chronobar")
        #expect(info["CFBundleExecutable"] as? String == "Chronobar")
        #expect(info["CFBundleShortVersionString"] as? String == "1.2.3")
        #expect(info[BuildVariant.dataFolderKey] == nil)
        #expect(info[BuildVariant.badgeKey] == nil)

        let variant = try BuildVariant(info: info)
        #expect(variant.dataFolder == "Chronobar")
        #expect(variant.badge == nil)
        #expect(variant.appName == "Chronobar")
    }

    /// The keys the script writes are the ones `BuildVariant` reads.
    @Test func theDevelopmentCopyGetsItsOwnBundleIDNameDataFolderAndBadge() throws {
        let info = try infoPlist(["--dev"])
        #expect(info["CFBundleIdentifier"] as? String == "io.github.nhall.chronobar.dev")
        #expect(info["CFBundleExecutable"] as? String == "ChronobarDev")

        let variant = try BuildVariant(info: info)
        #expect(variant.dataFolder == "Chronobar Dev")
        #expect(variant.badge == "DEV")
        #expect(variant.appName == "Chronobar Dev")
    }
}
