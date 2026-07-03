// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DotsUI",
    platforms: [
        .macOS("27.0"),
        .iOS("27.0")
    ],
    products: [
        .library(
            name: "DotsUI",
            targets: ["DotsUI"]
        )
    ],
    targets: [
        .target(
            name: "DotsUI",
            resources: [
                .process("Shaders/DotsShaders.metal")
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableExperimentalFeature("StrictConcurrency=complete"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        ),
        .testTarget(
            name: "DotsUITests",
            dependencies: ["DotsUI"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableExperimentalFeature("StrictConcurrency=complete"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
