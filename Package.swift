// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "UniversalControlHelper",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "UniversalControlCore", targets: ["UniversalControlCore"]),
        .executable(name: "UniversalControlHelper", targets: ["UniversalControlHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
    ],
    targets: [
        .target(name: "UniversalControlCore"),
        .executableTarget(
            name: "UniversalControlHelper",
            dependencies: [
                "UniversalControlCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("Network"),
            ]
        ),
        .testTarget(name: "UniversalControlCoreTests", dependencies: ["UniversalControlCore"]),
        .testTarget(name: "UniversalControlHelperTests", dependencies: ["UniversalControlHelper"]),
    ]
)
