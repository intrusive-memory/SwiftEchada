// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftEchada",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftEchada",
            targets: ["SwiftEchada"]
        ),
    ],
    dependencies: [
        // SwiftGuion for screenplay parsing
        .package(url: "https://github.com/stovak/SwiftGuion.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftEchada",
            dependencies: [
                .product(name: "SwiftGuion", package: "SwiftGuion")
            ]
        ),
        .testTarget(
            name: "SwiftEchadaTests",
            dependencies: ["SwiftEchada"],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
