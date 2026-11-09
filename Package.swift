// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpencodeUsage",
    platforms: [
        .macOS(.v26),
    ],
    targets: [
        .executableTarget(
            name: "OpencodeUsage",
            path: "Sources/OpencodeUsage",
            resources: [
                .copy("Resources/opencode-logo.png"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "OpencodeUsageTests",
            dependencies: [
                "OpencodeUsage",
            ],
            path: "Tests/OpencodeUsageTests",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
