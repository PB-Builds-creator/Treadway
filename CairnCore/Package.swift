// swift-tools-version: 6.0
import PackageDescription

// CairnCore is the pure, Foundation-only business-logic layer for the Cairn app.
// It contains NO SwiftUI, UIKit, SwiftData, or platform-UI code, so it compiles
// and unit-tests on any Swift toolchain (including Command Line Tools) and is
// shared by the app, the widget extension, and the App Intents extension.
let package = Package(
    name: "CairnCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "CairnCore", targets: ["CairnCore"])
    ],
    targets: [
        .target(
            name: "CairnCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "CairnCoreTests",
            dependencies: ["CairnCore"]
        ),
        // A dependency-free executable that re-runs the critical assertions using a
        // tiny built-in harness. Unlike the XCTest target (which needs full Xcode),
        // this compiles and RUNS on Command Line Tools, so the core logic can be
        // verified in any environment via `swift run cairncore-verify`.
        .executableTarget(
            name: "cairncore-verify",
            dependencies: ["CairnCore"]
        )
    ]
)
