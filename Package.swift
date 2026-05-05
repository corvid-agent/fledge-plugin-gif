// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "fledge-plugin-gif",
    targets: [
        .target(
            name: "GifLib",
            path: "Sources/GifLib"
        ),
        .executableTarget(
            name: "fledge-plugin-gif",
            dependencies: ["GifLib"],
            path: "Sources",
            exclude: ["GifLib"]
        ),
        .testTarget(
            name: "GifTests",
            dependencies: ["GifLib"],
            path: "Tests"
        ),
    ]
)
