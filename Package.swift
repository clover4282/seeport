// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "seeport",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "seeport",
            dependencies: ["Sparkle"],
            path: "Sources/seeport"
        )
    ]
)
