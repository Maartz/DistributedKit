// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SampleWorker",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "SampleWorker",
            dependencies: [
                .product(name: "DistributedKit", package: "DistributedKit"),
            ],
            path: "Sources"
        ),
    ],
    swiftLanguageModes: [.v6]
)
