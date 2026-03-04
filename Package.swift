// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "seeport",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "seeport",
            path: "Sources/seeport"
        )
    ]
)
