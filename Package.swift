// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ChiefKitStudio",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ChiefKitStudioCore", targets: ["ChiefKitStudioCore"]),
        .executable(name: "ChiefKitStudio", targets: ["ChiefKitStudio"])
    ],
    targets: [
        .target(
            name: "ChiefKitStudioCore",
            path: "Sources/ChiefKitStudioCore"
        ),
        .executableTarget(
            name: "ChiefKitStudio",
            dependencies: ["ChiefKitStudioCore"],
            path: "Sources/ChiefKitStudio",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ChiefKitStudioTests",
            dependencies: ["ChiefKitStudioCore", "ChiefKitStudio"],
            path: "Tests/ChiefKitStudioTests"
        )
    ]
)
