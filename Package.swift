// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chronobar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Chronobar", targets: ["Chronobar"]),
    ],
    dependencies: [
        // The only third-party package: the global play/pause shortcut and its recorder control.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", .upToNextMinor(from: "1.15.0")),
    ],
    targets: [
        .target(name: "ChronobarCore"),
        .executableTarget(
            name: "Chronobar",
            dependencies: [
                "ChronobarCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .testTarget(
            name: "ChronobarCoreTests",
            dependencies: ["ChronobarCore"]
        ),
    ]
)
