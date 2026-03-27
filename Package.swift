// swift-tools-version: 6.3

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "DistributedKit",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11)],
    products: [
        .library(name: "DistributedKit", targets: ["DistributedKit"]),
        .library(name: "DistributedKitTestKit", targets: ["DistributedKitTestKit"]),
    ],
    dependencies: [
        // Using branch: "main" because the last tagged beta (1.0.0-beta.3) targets
        // swift-tools-version 5.7 and is incompatible with Swift 6.3.
        .package(url: "https://github.com/apple/swift-distributed-actors.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .macro(
            name: "DistributedKitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/DistributedKitMacros"
        ),
        .target(
            name: "DistributedKit",
            dependencies: [
                "DistributedKitMacros",
                .product(name: "DistributedCluster", package: "swift-distributed-actors"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            path: "Sources/DistributedKit"
        ),
        .target(
            name: "DistributedKitTestKit",
            dependencies: [
                "DistributedKit",
                .product(name: "DistributedCluster", package: "swift-distributed-actors"),
            ],
            path: "Sources/DistributedKitTestKit"
        ),
        .testTarget(
            name: "DistributedKitTests",
            dependencies: [
                "DistributedKit",
                "DistributedKitTestKit",
                .product(name: "ServiceLifecycleTestKit", package: "swift-service-lifecycle"),
            ]
        ),
        .testTarget(
            name: "DistributedKitMacroTests",
            dependencies: [
                "DistributedKitMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
