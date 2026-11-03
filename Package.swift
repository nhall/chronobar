// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Chronobar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Chronobar", targets: ["Chronobar"]),
    ],
    targets: [
        .target(name: "ChronobarCore"),
        .executableTarget(
            name: "Chronobar",
            dependencies: ["ChronobarCore"]
        ),
        .testTarget(
            name: "ChronobarCoreTests",
            dependencies: ["ChronobarCore"]
        ),
    ]
)
