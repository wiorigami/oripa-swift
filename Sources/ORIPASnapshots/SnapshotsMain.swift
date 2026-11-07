// Headless SwiftUI snapshot renderer — local visual QA without Xcode/simulator.
//
//   swift run ORIPASnapshots <output-dir>
//
// Renders app screens through ImageRenderer (works headless on macOS) so the port can
// be compared with the web reference screenshots. The final scenario list is owned by
// the `ui-shell` workstream (ORIPAUI/SnapshotScenarios) and assembled here by
// `ci-release`.
import SwiftUI
import AppKit
import ORIPAUI
import ORIPACore

@main
struct SnapshotsMain {
    static func main() {
        let outDir = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : "build-snapshots"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let view = ORIPARootView().frame(width: 768, height: 1024)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("snapshot render failed")
            exit(1)
        }
        let path = (outDir as NSString).appendingPathComponent("root.png")
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}
