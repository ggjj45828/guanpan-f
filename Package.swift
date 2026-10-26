// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GuanpanFCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FCore", targets: ["FCore"]),
        .library(name: "FAdvisor", targets: ["FAdvisor"]),
        .library(name: "FLedgerWrite", targets: ["FLedgerWrite"])
    ],
    targets: [
        .target(name: "FCore"),
        .target(name: "FAdvisor", dependencies: ["FCore"]),
        .target(name: "FLedgerWrite", dependencies: ["FCore"]),
        .testTarget(name: "FCoreTests", dependencies: ["FCore", "FAdvisor", "FLedgerWrite"])
    ]
)
