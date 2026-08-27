// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "UniversalControlInputFix",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "UniInputCore", targets: ["UniInputCore"]),
        .executable(name: "UniInputFix", targets: ["UniInputFix"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
    ],
    targets: [
        .target(name: "UniInputCore"),
        .executableTarget(
            name: "UniInputFix",
            dependencies: [
                "UniInputCore",
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
        .testTarget(name: "UniInputCoreTests", dependencies: ["UniInputCore"]),
    ]
)
