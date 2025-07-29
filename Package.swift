// swift-tools-version: 5.4

import PackageDescription

let package = Package(
    name: "imageprep",
    targets: [
        .executableTarget(
            name: "imageprep",
            path: "imageprep",
            exclude: [
                // File not needed for Linux build (so far...)
                "Info.plist"
            ]
        )
    ]
)
