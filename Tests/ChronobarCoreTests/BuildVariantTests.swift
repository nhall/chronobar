import Foundation
import Testing
import ChronobarCore

@Suite struct BuildVariantTests {
    let applicationSupport = URL(fileURLWithPath: "/Users/someone/Library/Application Support", isDirectory: true)

    @Test func theReleaseBuildKeepsItsDataInTheChronobarFolder() throws {
        let release: [String: Any] = ["CFBundleIdentifier": "io.github.nhall.chronobar", "CFBundleName": "Chronobar"]
        let variant = try BuildVariant(info: release)
        #expect(variant.storageRoot(in: applicationSupport).path
            == "/Users/someone/Library/Application Support/Chronobar")
        #expect(variant.badge == nil)
        #expect(variant.appName == "Chronobar")
    }

    /// `swift run` has no Info.plist of its own.
    @Test func aBuildWithoutAnInfoPlistKeepsItsDataInTheChronobarFolder() throws {
        let variant = try BuildVariant(info: nil)
        #expect(variant.storageRoot(in: applicationSupport).path
            == "/Users/someone/Library/Application Support/Chronobar")
        #expect(variant.badge == nil)
        #expect(variant.appName == "Chronobar")
    }

    @Test func aDevelopmentCopyKeepsItsDataInItsOwnFolderAndCarriesABadgeAndItsOwnName() throws {
        let development: [String: Any] = [
            "CFBundleIdentifier": "io.github.nhall.chronobar.dev",
            "CFBundleName": "Chronobar Dev",
            "ChronobarDataFolder": "Chronobar Dev",
            "ChronobarBadge": "DEV",
        ]
        let variant = try BuildVariant(info: development)
        #expect(variant.storageRoot(in: applicationSupport).path
            == "/Users/someone/Library/Application Support/Chronobar Dev")
        #expect(variant.badge == "DEV")
        #expect(variant.appName == "Chronobar Dev")
    }

    /// A copy that asks for its own folder and names it wrongly must not fall back to the everyday folder.
    @Test(arguments: ["", "  ", ".", "..", "../Chronobar", "Chronobar Dev/days"])
    func aDataFolderThatIsNotOnePlainFolderNameIsRefused(_ name: String) {
        #expect(throws: BuildVariant.InvalidDataFolder.self) {
            try BuildVariant(info: ["ChronobarDataFolder": name])
        }
    }

    @Test func aDataFolderThatIsNotTextIsRefused() {
        #expect(throws: BuildVariant.InvalidDataFolder.self) {
            try BuildVariant(info: ["ChronobarDataFolder": 42])
        }
    }
}
