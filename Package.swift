// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Huayi",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Huayi",
            targets: ["Huayi"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Huayi",
            path: "Sources/GlobalSelectionTranslator"
        )
    ]
)
