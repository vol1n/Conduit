// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TodoServer",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(path: "../Shared"),
        .package(path: "../../ConduitServer"),
    ],
    targets: [
        .executableTarget(
            name: "TodoServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "ConduitServer", package: "ConduitServer"),
                .product(name: "TodoShared", package: "Shared"),
            ],
            path: "Sources"
        )
    ]
)
