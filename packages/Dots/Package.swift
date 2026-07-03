// swift-tools-version: 6.2

import PackageDescription

let tcaRevision = "f670b08d91e9026e614e8b7aa6faea4dfa1313af"
let pureSwiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency=complete"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]
let featureSwiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableExperimentalFeature("StrictConcurrency=complete"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "Dots",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    products: [
        .library(name: "DotsDomain", targets: ["DotsDomain"]),
        .library(name: "DotsEngine", targets: ["DotsEngine"]),
        .library(name: "DotsClients", targets: ["DotsClients"]),
        .library(name: "DotsFeatures", targets: ["DotsFeatures"]),
        .library(name: "DotsRoot", targets: ["DotsRoot"])
    ],
    dependencies: [
        .package(path: "../DotsUI"),
        .package(url: "https://github.com/pointfreeco/TCA26", revision: tcaRevision),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.14.1"),
        .package(url: "https://github.com/pointfreeco/swift-clocks", branch: "clocks-2"),
        .package(url: "https://github.com/anthropics/ClaudeForFoundationModels", from: "0.1.2")
    ],
    targets: [
        .target(
            name: "DotsDomain",
            swiftSettings: pureSwiftSettings
        ),
        .target(
            name: "DotsEngine",
            dependencies: ["DotsDomain"],
            swiftSettings: pureSwiftSettings
        ),
        .target(
            name: "DotsClients",
            dependencies: [
                "DotsDomain",
                "DotsEngine",
                .product(name: "ClaudeForFoundationModels", package: "ClaudeForFoundationModels"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            swiftSettings: pureSwiftSettings
        ),
        .target(
            name: "DotsFeatures",
            dependencies: [
                "DotsClients",
                "DotsDomain",
                "DotsEngine",
                .product(name: "DotsUI", package: "DotsUI"),
                .product(name: "ComposableArchitecture2", package: "TCA26"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            swiftSettings: featureSwiftSettings
        ),
        .target(
            name: "DotsRoot",
            dependencies: [
                "DotsFeatures",
                .product(name: "ComposableArchitecture2", package: "TCA26")
            ],
            swiftSettings: featureSwiftSettings
        ),
        .testTarget(
            name: "DotsDomainTests",
            dependencies: ["DotsDomain"],
            swiftSettings: pureSwiftSettings
        ),
        .testTarget(
            name: "DotsClientsTests",
            dependencies: ["DotsClients", "DotsDomain", "DotsEngine"],
            swiftSettings: pureSwiftSettings
        ),
        .testTarget(
            name: "DotsEngineTests",
            dependencies: ["DotsDomain", "DotsEngine"],
            swiftSettings: pureSwiftSettings
        ),
        .testTarget(
            name: "DotsFeaturesTests",
            dependencies: [
                "DotsFeatures",
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "ComposableArchitecture2", package: "TCA26"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            ],
            swiftSettings: featureSwiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
