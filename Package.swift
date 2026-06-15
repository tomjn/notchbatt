// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchBatt",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "NotchBattCore"),
        .executableTarget(
            name: "notchbatt",
            dependencies: ["NotchBattCore"]
        ),
        .testTarget(
            name: "NotchBattCoreTests",
            dependencies: ["NotchBattCore"]
        ),
    ]
)
