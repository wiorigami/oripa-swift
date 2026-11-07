// swift-tools-version:5.9
//
// ORIPA — native Apple (iOS/iPadOS + macOS) port of ORIPA for Android 0.2.3.3.
//
// Build systems:
//   * SwiftPM (this file)  — ORIPACore logic + ORIPAUI SwiftUI + macOS app + snapshot tool
//                            + hermetic test runner. Buildable locally with Command Line
//                            Tools only (`swift build`, `swift run ORIPATests`,
//                            `swift run ORIPASnapshots`). NOTE: this Mac's Command Line
//                            Tools toolchain has no XCTest module, therefore tests are a
//                            plain executable (Tests/ORIPATests) instead of a testTarget;
//                            `swift run ORIPATests` is the single test entry point locally
//                            and in CI.
//   * XcodeGen (project.yml) — iOS/iPadOS app bundle, generated with `xcodegen generate`
//                            and built in GitHub Actions with a full Xcode.
//
// The iOS app target depends on the local Swift package products ORIPACore + ORIPAUI.
// Keep this file in sync with project.yml (iOS deployment target 16.0, macOS 13.0).
import PackageDescription

let package = Package(
    name: "ORIPA",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "ORIPACore", targets: ["ORIPACore"]),
        .library(name: "ORIPAUI", targets: ["ORIPAUI"]),
        .executable(name: "ORIPAMac", targets: ["ORIPAMac"]),
        .executable(name: "ORIPASnapshots", targets: ["ORIPASnapshots"]),
        .executable(name: "ORIPATests", targets: ["ORIPATests"]),
        .executable(name: "ORIPAIntegration", targets: ["ORIPAIntegration"]),
    ],
    targets: [
        .target(
            name: "ORIPACore",
            path: "Sources/ORIPACore"
        ),
        .target(
            name: "ORIPAUI",
            dependencies: ["ORIPACore"],
            path: "Sources/ORIPAUI",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "ORIPAMac",
            dependencies: ["ORIPAUI"],
            path: "Sources/ORIPAMac"
        ),
        .executableTarget(
            name: "ORIPASnapshots",
            dependencies: ["ORIPAUI"],
            path: "Sources/ORIPASnapshots"
        ),
        .executableTarget(
            name: "ORIPATests",
            dependencies: ["ORIPACore"],
            path: "Tests/ORIPATests"
        ),
        // End-to-end integration checks that exercise the real app layer (ProjectStore
        // persistence, EditorSession drawing/save/reload, autosave recovery, import,
        // folding and exports) headlessly. Local: `swift run ORIPAIntegration`; CI runs it
        // in the test job (macOS runner).
        .executableTarget(
            name: "ORIPAIntegration",
            dependencies: ["ORIPACore", "ORIPAUI"],
            path: "Tests/ORIPAIntegration"
        ),
    ]
)
