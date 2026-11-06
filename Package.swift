// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chronobar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Chronobar", targets: ["Chronobar"]),
    ],
    dependencies: [
        // Pinned: 1.16.0 and later use SwiftUI macros (#Preview, @State, @Entry), which the
        // Command Line Tools can't expand.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.15.0"),
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
        .testTarget(name: "ChronobarCoreTests", dependencies: ["ChronobarCore"]),
        // What only the app target knows, such as the running colors as SwiftUI draws them.
        .testTarget(name: "ChronobarTests", dependencies: ["ChronobarCore", "Chronobar"]),
        // The scripts under scripts/, run as a developer or the bundling script runs them.
        .testTarget(name: "ScriptTests", dependencies: ["ChronobarCore"]),
    ]
)
