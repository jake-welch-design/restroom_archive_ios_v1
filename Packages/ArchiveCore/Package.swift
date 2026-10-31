// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ArchiveCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ArchiveCore",
            targets: ["ArchiveCore"]
        )
    ],
    targets: [
        .target(
            name: "ArchiveCore",
            path: "Sources/ArchiveCore"
        ),
        .executableTarget(
            name: "ArchiveCoreVerify",
            dependencies: ["ArchiveCore"],
            path: "Sources/ArchiveCoreVerify"
        ),
        .testTarget(
            name: "ArchiveCoreTests",
            dependencies: ["ArchiveCore"],
            path: "Tests/ArchiveCoreTests"
        )
    ]
)
