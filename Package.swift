// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartFileSorter",
    defaultLocalization: "uk",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SmartFileSorter", targets: ["SmartFileSorter"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "SmartFileSorter",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/SmartFileSorter",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SmartFileSorterTests",
            dependencies: ["SmartFileSorter"],
            path: "Tests/SmartFileSorterTests"
        )
    ]
)
