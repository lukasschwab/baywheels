// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BayWheelsMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "BayWheelsMenuBar",
            path: "Sources/BayWheelsMenuBar"
        )
    ]
)
