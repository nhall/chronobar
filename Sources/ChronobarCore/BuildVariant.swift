import Foundation

/// Which copy of Chronobar this is: the everyday one, or a development copy that
/// `scripts/bundle-app.sh --dev` builds to run next to it. Read from the app's Info.plist.
///
/// Settings, the Selected Project, the heartbeat and start at login follow the bundle ID on their own;
/// the data folder doesn't, so a development copy names its own folder here.
public struct BuildVariant: Equatable, Sendable {
    /// Info.plist key naming the folder in Application Support that holds the Project list and Day files.
    public static let dataFolderKey = "ChronobarDataFolder"
    /// Info.plist key for a short label shown on the Dock icon, so the copies can be told apart.
    public static let dockBadgeKey = "ChronobarDockBadge"

    public static let defaultDataFolder = "Chronobar"

    /// The Info.plist names a data folder that isn't one plain folder name. Refused rather than
    /// replaced with the everyday folder, which a development copy must never write to.
    public struct InvalidDataFolder: Error, CustomStringConvertible {
        public let value: String
        public var description: String { "\(BuildVariant.dataFolderKey) in Info.plist is not a folder name: \(value)" }
    }

    public let dataFolder: String
    public let dockBadge: String?

    /// `info` is the bundle's Info.plist; `nil` (as under `swift run`) is the everyday copy.
    public init(info: [String: Any]?) throws {
        if let value = info?[Self.dataFolderKey] {
            guard let name = value as? String, Self.isPlainFolderName(name) else {
                throw InvalidDataFolder(value: String(describing: value))
            }
            dataFolder = name
        } else {
            dataFolder = Self.defaultDataFolder
        }
        dockBadge = info?[Self.dockBadgeKey] as? String
    }

    /// The data folder, inside `applicationSupport` (`~/Library/Application Support`).
    public func storageRoot(in applicationSupport: URL) -> URL {
        applicationSupport.appendingPathComponent(dataFolder, isDirectory: true)
    }

    private static func isPlainFolderName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && name != "." && name != ".."
            && !name.contains("/") && !name.contains(":")
    }
}
