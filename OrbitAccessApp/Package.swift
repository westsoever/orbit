// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrbitAccessApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OrbitAccessApp", targets: ["OrbitAccessApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "OrbitAccessApp",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: ".",
            exclude: [
                "OrbitAccessApp.app",
                "ISSUE_REPORT.md",
                "OrbitAccessApp.xcodeproj",
                "project.yml",
                "OrbitAccessApp.entitlements",
                "Resources/Info.plist",
                "Resources/Info.bundle.plist",
                "Resources/orbit-icon.svg",
                "Package.swift",
            ],
            sources: [
                "App",
                "IPC",
                "Models",
                "Services",
                "Stores",
                "AIFunctions",
                "Extensions",
                "Views",
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=minimal"]),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
