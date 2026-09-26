// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StreamingText",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "StreamingText", targets: ["StreamingText"]),
    ],
    targets: [
        .target(name: "StreamingText"),
        .testTarget(name: "StreamingTextTests", dependencies: ["StreamingText"]),
    ]
)
