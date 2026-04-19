// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Util",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Util", targets: ["Util"]),
    ],
    targets: [
        .target(name: "Util"),
        .testTarget(name: "UtilTests", dependencies: ["Util"]),
    ]
)
