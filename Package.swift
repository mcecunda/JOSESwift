// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JOSESwift",
    platforms: [
        .iOS(.v11),
        .watchOS(.v4),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "JOSESwift",
            type: .dynamic,
            targets: ["JOSESwift"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "JOSESwift", dependencies: [], path: "JOSESwift/Sources"),
    ]
)
