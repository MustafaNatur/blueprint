// swift-tools-version: 6.2

import PackageDescription

let iconKit = Target.Dependency.product(name: "IconKit", package: "icon-kit")
let argumentParser = Target.Dependency.product(name: "ArgumentParser", package: "swift-argument-parser")

let package = Package(
    name: "blueprint",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "blueprint", targets: ["blueprint"]),
    ],
    dependencies: [
        .package(url: "https://github.com/rozd/icon-kit", from: "1.2.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "blueprint",
            dependencies: [
                "BlueprintCore",
                "IconComposerBlueprint",
                "AppIconSetBlueprint",
                argumentParser
            ]
        ),
        .target(
            name: "BlueprintCore"
        ),
        .target(
            name: "IconComposerBlueprint",
            dependencies: [
                "BlueprintCore",
                iconKit
            ]
        ),
        .target(
            name: "AppIconSetBlueprint",
            dependencies: [
                "BlueprintCore"
            ]
        ),
        .target(
            name: "BlueprintTestSupport",
            dependencies: [
                "AppIconSetBlueprint",
                iconKit
            ],
            path: "Tests/BlueprintTestSupport"
        ),
        .testTarget(
            name: "BlueprintCoreTests",
            dependencies: [
                "BlueprintCore"
            ]
        ),
        .testTarget(
            name: "IconComposerBlueprintTests",
            dependencies: [
                "IconComposerBlueprint",
                "BlueprintTestSupport",
                iconKit
            ]
        ),
        .testTarget(
            name: "AppIconSetBlueprintTests",
            dependencies: [
                "AppIconSetBlueprint",
                "BlueprintTestSupport"
            ]
        ),
        .testTarget(
            name: "blueprintTests",
            dependencies: [
                "blueprint",
                "BlueprintTestSupport"
            ]
        ),
    ]
)
