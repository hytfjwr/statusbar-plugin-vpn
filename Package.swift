// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VPNPlugin",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "VPNPlugin", type: .dynamic, targets: ["VPNPlugin"]),
    ],
    dependencies: [
        .package(path: "../macos-status-bar/StatusBarKit"),
    ],
    targets: [
        .target(
            name: "VPNPlugin",
            dependencies: [
                .product(name: "StatusBarKit", package: "StatusBarKit"),
            ]
        ),
    ]
)
