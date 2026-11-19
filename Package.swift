// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Keylume",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KeylumeKit", targets: ["KeylumeKit"]),
        .executable(name: "keylume", targets: ["keylume"]),
        .executable(name: "KeylumeApp", targets: ["KeylumeApp"]),
    ],
    targets: [
        .target(name: "KeylumeKit", linkerSettings: [.linkedFramework("IOKit")]),
        .executableTarget(name: "keylume", dependencies: ["KeylumeKit"]),
        .executableTarget(name: "KeylumeApp", dependencies: ["KeylumeKit"]),
        .testTarget(name: "KeylumeKitTests", dependencies: ["KeylumeKit"]),
    ]
)
