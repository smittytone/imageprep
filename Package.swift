// swift-tools-version: 5.4

import PackageDescription

let package = Package(
    name: "imageprep",
    dependencies: [
        .package(url: "https://github.com/smittytone/clicore", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "imageprep",
            dependencies: [
                .product(name: "Clicore", package: "clicore"),
            ],
            path: "imageprep",
            exclude: [
                // File not needed for Linux build (so far...)
                "Info.plist"
            ]
        )
    ]
)
