// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hunch",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Hunch",
            dependencies: [],
            path: "Sources/Hunch"
        ),
        .testTarget(
            name: "HunchTests",
            dependencies: ["Hunch"],
            path: "Tests/HunchTests"
        )
    ]
)
