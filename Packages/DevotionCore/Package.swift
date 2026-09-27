// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DevotionCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DevotionCore", targets: ["DevotionCore"]),
    ],
    targets: [
        .target(name: "DevotionCore"),
        .testTarget(name: "DevotionCoreTests", dependencies: ["DevotionCore"]),
    ]
)
