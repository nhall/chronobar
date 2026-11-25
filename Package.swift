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
        // `chronobar mcp`. Its Package@swift-6.0.swift lets this package stay at tools version 6.0.
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", exact: "0.12.1"),
        // Capped, not used directly: the SDK's dependencies, held to the last releases whose manifests
        // Swift 6.0 and 6.1 (Command Line Tools 16) can read. Later ones need Swift 6.2, so without
        // these caps SwiftPM resolves to them and the Homebrew build fails on Command Line Tools 16.
        .package(url: "https://github.com/apple/swift-log.git", "1.5.0"..<"1.12.0"),
        .package(url: "https://github.com/apple/swift-system.git", "1.4.0"..<"1.7.0"),
        .package(url: "https://github.com/apple/swift-collections.git", "1.1.0"..<"1.7.0"),
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
        .executableTarget(
            name: "ChronobarCLI",
            dependencies: ["ChronobarCore", "ChronobarOperations", .product(name: "MCP", package: "swift-sdk")]
        ),
        .testTarget(name: "ChronobarCoreTests", dependencies: ["ChronobarCore"]),
        .testTarget(name: "OperationsTests", dependencies: ["ChronobarCore", "ChronobarOperations"]),
        // How the `chronobar` command reads its arguments.
        .testTarget(name: "CLITests", dependencies: ["ChronobarCore", "ChronobarOperations", "ChronobarCLI"]),
        // `chronobar mcp`'s tools, called as a session would, against a real Core in a temporary folder.
        .testTarget(
            name: "MCPTests",
            dependencies: ["ChronobarCore", "ChronobarOperations", "ChronobarCLI",
                           .product(name: "MCP", package: "swift-sdk")]
        ),
        // What only the app target knows, such as the running colors as SwiftUI draws them.
        .testTarget(name: "ChronobarTests", dependencies: ["ChronobarCore", "Chronobar"]),
        // The scripts under scripts/, run as a developer or the bundling script runs them.
        .testTarget(name: "ScriptTests", dependencies: ["ChronobarCore"]),
    ]
)
