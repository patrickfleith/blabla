// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Blabla",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Blabla", targets: ["BlablaApp"]),
    ],
    targets: [
        .executableTarget(
            name: "BlablaApp",
            path: "Sources/BlablaApp"
        ),
        .testTarget(
            name: "BlablaTests",
            dependencies: ["BlablaApp"],
            path: "Tests/BlablaTests"
        ),
    ]
)
