// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ChiefKitStudio",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ChiefKitStudioCore", targets: ["ChiefKitStudioCore"]),
        .library(name: "ChiefKitAST", targets: ["ChiefKitAST"]),
        .library(name: "ChiefKitDesignSystem", targets: ["ChiefKitDesignSystem"]),
        .library(name: "ChiefKitSecurity", targets: ["ChiefKitSecurity"]),
        .library(name: "ChiefKitBlueprints", targets: ["ChiefKitBlueprints"]),
        .executable(name: "ChiefKitStudio", targets: ["ChiefKitStudio"])
    ],
    targets: [
        .target(
            name: "ChiefKitStudioCore",
            path: "Sources/ChiefKitStudioCore"
        ),
        .target(
            name: "ChiefKitAST",
            dependencies: ["ChiefKitStudioCore"],
            path: "Sources/ChiefKitAST"
        ),
        .target(
            name: "ChiefKitDesignSystem",
            dependencies: ["ChiefKitStudioCore"],
            path: "Sources/ChiefKitDesignSystem"
        ),
        .target(
            name: "ChiefKitSecurity",
            dependencies: ["ChiefKitStudioCore"],
            path: "Sources/ChiefKitSecurity"
        ),
        .target(
            name: "ChiefKitBlueprints",
            dependencies: ["ChiefKitStudioCore"],
            path: "Sources/ChiefKitBlueprints"
        ),
        .executableTarget(
            name: "ChiefKitStudio",
            dependencies: [
                "ChiefKitStudioCore",
                "ChiefKitAST",
                "ChiefKitDesignSystem",
                "ChiefKitSecurity",
                "ChiefKitBlueprints"
            ],
            path: "Sources/ChiefKitStudio",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ChiefKitStudioTests",
            dependencies: [
                "ChiefKitStudioCore",
                "ChiefKitAST",
                "ChiefKitDesignSystem",
                "ChiefKitSecurity",
                "ChiefKitBlueprints",
                "ChiefKitStudio"
            ],
            path: "Tests/ChiefKitStudioTests"
        )
    ]
)

