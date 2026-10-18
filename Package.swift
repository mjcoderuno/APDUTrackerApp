// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BioCard",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "BioCardApp", targets: ["BioCardApp"]),
        .executable(name: "BioCardCLI", targets: ["BioCardCLI"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BioCardCore",
            dependencies: [],
            path: "Sources/BioCardCore"
        ),
        .target(
            name: "BioCardUI",
            dependencies: ["BioCardCore"],
            path: "Sources/BioCardUI"
        ),
        .executableTarget(
            name: "BioCardApp",
            dependencies: ["BioCardCore", "BioCardUI"],
            path: "Sources/BioCardApp"
        ),
        .executableTarget(
            name: "BioCardCLI",
            dependencies: ["BioCardCore"],
            path: "Sources/BioCardCLI"
        ),
        .testTarget(
            name: "BioCardTests",
            dependencies: ["BioCardCore"],
            path: "Tests/BioCardTests"
        )
    ]
)
