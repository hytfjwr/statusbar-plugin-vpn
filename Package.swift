// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VPNPlugin",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "VPNPlugin", type: .dynamic, targets: ["VPNPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hytfjwr/StatusBarKit", from: "1.0.0"),
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
