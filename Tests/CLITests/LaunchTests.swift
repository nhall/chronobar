import Foundation
import Testing
import ChronobarCore
@testable import ChronobarCLI

/// Which app the command launches when nothing answers on the socket: the one installed beside it.
@Suite struct LaunchTests {
    /// A Homebrew-shaped install in a temporary folder: `Cellar/chronobar/2.0.0/{bin/chronobar, Chronobar.app}`
    /// with `bin/chronobar` linked from the prefix's `bin`, as `brew link` does.
    private func install(apps: [String]) throws -> (root: URL, linked: URL, keg: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let keg = root.appendingPathComponent("Cellar/chronobar/2.0.0")
        let files = FileManager.default
        try files.createDirectory(at: keg.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try Data().write(to: keg.appendingPathComponent("bin/chronobar"))
        for app in apps {
            try files.createDirectory(at: keg.appendingPathComponent(app), withIntermediateDirectories: true)
        }
        let linked = root.appendingPathComponent("bin/chronobar")
        try files.createDirectory(at: linked.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.createSymbolicLink(atPath: linked.path, withDestinationPath: "../Cellar/chronobar/2.0.0/bin/chronobar")
        return (root, linked, keg)
    }

    @Test func theAppBesideTheLinkedCommandIsFound() throws {
        let (root, linked, keg) = try install(apps: ["Chronobar.app"])
        defer { try? FileManager.default.removeItem(at: root) }
        let app = BuildVariant.Copy.everyday.app(besideExecutable: linked)
        #expect(app?.resolvingSymlinksInPath().path
                == keg.appendingPathComponent("Chronobar.app").resolvingSymlinksInPath().path)
    }

    @Test func theDevelopmentCopyIsFoundByItsOwnName() throws {
        let (root, linked, keg) = try install(apps: ["Chronobar.app", "Chronobar Dev.app"])
        defer { try? FileManager.default.removeItem(at: root) }
        let app = BuildVariant.Copy.development.app(besideExecutable: linked)
        #expect(app?.resolvingSymlinksInPath().path
                == keg.appendingPathComponent("Chronobar Dev.app").resolvingSymlinksInPath().path)
    }

    @Test func noAppBesideTheCommandFindsNothing() throws {
        let (root, linked, _) = try install(apps: [])
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(BuildVariant.Copy.everyday.app(besideExecutable: linked) == nil)
    }
}
