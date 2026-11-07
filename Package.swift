// swift-tools-version:5.9
//
// ORIPA — native Apple (iOS/iPadOS + macOS) port of ORIPA for Android 0.2.3.3.
//
// Build systems:
//   * SwiftPM (this file)  — ORIPACore logic + ORIPAUI SwiftUI + macOS app + snapshot tool.
//                            Buildable locally with Command Line Tools only (`swift build`,
//                            `swift test`, `swift run ORIPASnapshots`).
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
        .testTarget(
            name: "ORIPACoreTests",
            dependencies: ["ORIPACore"],
            path: "Tests/ORIPACoreTests"
        ),
    ]
)
