// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Nudgie",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NudgieCore", targets: ["NudgieCore"]),
        .executable(name: "Nudgie", targets: ["Nudgie"]),
    ],
    targets: [
        .target(name: "NudgieCore"),
        .executableTarget(
            name: "Nudgie",
            dependencies: ["NudgieCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "NudgieCoreTests", dependencies: ["NudgieCore"]),
        .testTarget(name: "NudgieAppTests", dependencies: ["Nudgie"]),
    ]
)
