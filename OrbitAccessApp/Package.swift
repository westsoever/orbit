// swift-tools-version: 6.0
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
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
