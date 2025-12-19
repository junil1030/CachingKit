// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CachingKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "CachingKit",
            targets: ["CachingKit"]
        )
    ],
    targets: [
        .target(
            name: "CachingKit",
            path: "Sources/CachingKit"
        )
    ]
)
