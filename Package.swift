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
                .copy("Resources/AppIcon.icns"),
            ]
        ),
        // WidgetKit desktop widget. SwiftPM has no app-extension product type,
        // so the Makefile assembles this target's binary into a .appex and
        // embeds it in the app bundle (see the bundle-widget target).
        .executableTarget(
            name: "OpencodeUsageWidget",
            path: "Sources/Widget"
        ),
        .testTarget(
            name: "OpencodeUsageTests",
            dependencies: [
                "OpencodeUsage",
            ],
            path: "Tests/OpencodeUsageTests"
        ),
    ]
)
