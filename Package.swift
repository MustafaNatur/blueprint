// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "blueprint",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "blueprint", targets: ["blueprint"]),
        .library(name: "BlueprintKit", targets: ["BlueprintKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/rozd/icon-kit", from: "1.2.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "BlueprintKit",
            dependencies: [.product(name: "IconKit", package: "icon-kit")]
        ),
        .executableTarget(
            name: "blueprint",
            dependencies: [
                "BlueprintKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "BlueprintKitTests", dependencies: ["BlueprintKit"]),
    ]
)
