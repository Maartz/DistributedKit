// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SupervisionDemo",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "SupervisionDemo",
            dependencies: [
                .product(name: "DistributedKit", package: "DistributedKit"),
            ],
            path: "Sources"
        ),
    ],
    swiftLanguageModes: [.v6]
)
