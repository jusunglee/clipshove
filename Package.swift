// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clipshove",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "Clipshove",
            dependencies: ["HotKey"],
            path: "Sources/Clipshove"
        ),
    ]
)
