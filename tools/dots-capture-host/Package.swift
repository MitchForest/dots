// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "dots-capture-host",
    platforms: [.macOS("27.0")],
    dependencies: [
        .package(path: "../../packages/Dots")
    ],
    targets: [
        .executableTarget(
            name: "dots-capture-host",
            dependencies: [
                .product(name: "DotsClients", package: "Dots"),
                .product(name: "DotsDomain", package: "Dots"),
                .product(name: "DotsEngine", package: "Dots")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
