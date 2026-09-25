// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pretype",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Pretype",
            dependencies: [],
            path: "Sources/Pretype"
        ),
        .testTarget(
            name: "PretypeTests",
            dependencies: ["Pretype"],
            path: "Tests/PretypeTests"
        )
    ]
)
