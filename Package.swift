// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chronobar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Chronobar", targets: ["Chronobar"]),
        // The `chronobar` command. Built as `chronobar-cli` because a file system that ignores case can't
        // hold it next to the app's `Chronobar` in one build folder; scripts/bundle-app.sh renames it.
        .executable(name: "chronobar-cli", targets: ["ChronobarCLI"]),
    ],
    dependencies: [
        // Pinned: 1.16.0 and later use SwiftUI macros (#Preview, @State, @Entry), which the
        // Command Line Tools can't expand.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.15.0"),
    ],
    targets: [
        .target(name: "ChronobarCore"),
        // Named requests from outside the app (the command line, MCP), and the socket they come over.
        .target(name: "ChronobarOperations", dependencies: ["ChronobarCore"]),
        .executableTarget(
            name: "Chronobar",
            dependencies: [
                "ChronobarCore",
                "ChronobarOperations",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .executableTarget(name: "ChronobarCLI", dependencies: ["ChronobarCore", "ChronobarOperations"]),
        .testTarget(name: "ChronobarCoreTests", dependencies: ["ChronobarCore"]),
        .testTarget(name: "OperationsTests", dependencies: ["ChronobarCore", "ChronobarOperations"]),
        // What only the app target knows, such as the running colors as SwiftUI draws them.
        .testTarget(name: "ChronobarTests", dependencies: ["ChronobarCore", "Chronobar"]),
        // The scripts under scripts/, run as a developer or the bundling script runs them.
        .testTarget(name: "ScriptTests", dependencies: ["ChronobarCore"]),
    ]
)
