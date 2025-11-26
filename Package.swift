// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Conduit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Conduit",
            targets: ["Conduit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", branch: "main")
    ],
    targets: [
        .target(
            name: "Core",
        ),
        .target(
            name: "Conduit",
            dependencies: [
                "ConduitMacro",
                "Core",
            ]
        ),
        .macro(
            name: "ConduitMacro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "Core",
            ]
        ),
    ]
)
