// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Backend",
    platforms: [
        .macOS(.v13), // ScreenCaptureKit requires macOS 12.3+
    ],
    products: [
        .library(name: "Backend", targets: ["BackendLib"]),
        .executable(name: "BackendCLI", targets: ["BackendCLI"]),
    ],
    targets: [
        // Core logic library
        .target(
            name: "BackendLib",
            path: "Sources/BackendLib"
        ),
        // Command-line interface
        .executableTarget(
            name: "BackendCLI",
            dependencies: ["BackendLib"],
            path: "Sources/BackendCLI"
        ),
    ],
)
