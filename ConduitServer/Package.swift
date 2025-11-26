// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConduitServer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConduitServer",
            targets: ["ConduitServer"])
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.1"),
    ],
    targets: [
        .target(
            name: "ConduitServer",
            dependencies: [
                .product(name: "Conduit", package: "Conduit"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        )
    ]
)
