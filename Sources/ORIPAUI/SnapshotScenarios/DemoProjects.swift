// Demo projects for the headless snapshot scenarios (`swift run ORIPASnapshots`).
//
// The reference screenshots show seeded crease-pattern projects ("crane base",
// "origami bird", "untitled", …). This file generates small synthetic crease patterns as
// PNG thumbnails with CoreGraphics (headless-safe, no window server) and writes OPXC
// project files that carry a snapshot marker. The marker is understood by the snapshot-only
// preview renderer installed in `SnapshotScenarios.makeAll()`, so the preview screen can be
// rendered with real line art before the ORIPACore/Canvas renderers are wired in.
import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// One synthetic CP line of the demo patterns (normalised coordinates, Y down).
enum DemoLineKind {
    case boundary
    case mountain
    case valley
    case flat
}

struct DemoLine {
    var x0: CGFloat
    var y0: CGFloat
    var x1: CGFloat
    var y1: CGFloat
    var kind: DemoLineKind
}

enum DemoProjects {

    // MARK: Patterns

    /// Demo CP line art, roughly matching the reference screenshots' thumbnails.
    static func lines(for pattern: String) -> [DemoLine] {
        let boundary: [DemoLine] = [
            DemoLine(x0: 0.03, y0: 0.03, x1: 0.97, y1: 0.03, kind: .boundary),
            DemoLine(x0: 0.97, y0: 0.03, x1: 0.97, y1: 0.97, kind: .boundary),
            DemoLine(x0: 0.97, y0: 0.97, x1: 0.03, y1: 0.97, kind: .boundary),
            DemoLine(x0: 0.03, y0: 0.97, x1: 0.03, y1: 0.03, kind: .boundary),
        ]
        switch pattern {
        case "bird":
            return boundary + [
                DemoLine(x0: 0.5, y0: 0.03, x1: 0.5, y1: 0.5, kind: .mountain),
                DemoLine(x0: 0.5, y0: 0.5, x1: 0.97, y1: 0.5, kind: .mountain),
                DemoLine(x0: 0.03, y0: 0.97, x1: 0.5, y1: 0.5, kind: .mountain),
                DemoLine(x0: 0.03, y0: 0.5, x1: 0.5, y1: 0.5, kind: .valley),
                DemoLine(x0: 0.5, y0: 0.5, x1: 0.97, y1: 0.97, kind: .valley),
            ]
        case "crane":
            return boundary + [
                DemoLine(x0: 0.03, y0: 0.5, x1: 0.5, y1: 0.5, kind: .mountain),
                DemoLine(x0: 0.5, y0: 0.03, x1: 0.5, y1: 0.5, kind: .mountain),
                DemoLine(x0: 0.03, y0: 0.03, x1: 0.5, y1: 0.5, kind: .valley),
                DemoLine(x0: 0.5, y0: 0.5, x1: 0.97, y1: 0.5, kind: .valley),
                DemoLine(x0: 0.5, y0: 0.5, x1: 0.97, y1: 0.97, kind: .flat),
                DemoLine(x0: 0.5, y0: 0.5, x1: 0.97, y1: 0.5, kind: .flat),
            ]
        case "test":
            return boundary + [
                DemoLine(x0: 0.03, y0: 0.03, x1: 0.97, y1: 0.97, kind: .mountain),
                DemoLine(x0: 0.97, y0: 0.03, x1: 0.03, y1: 0.97, kind: .mountain),
                DemoLine(x0: 0.03, y0: 0.5, x1: 0.97, y1: 0.5, kind: .valley),
                DemoLine(x0: 0.5, y0: 0.03, x1: 0.5, y1: 0.97, kind: .valley),
            ]
        case "hydrangea":
            return boundary + [
                DemoLine(x0: 0.03, y0: 0.03, x1: 0.5, y1: 0.5, kind: .mountain),
                DemoLine(x0: 0.97, y0: 0.03, x1: 0.5, y1: 0.5, kind: .mountain),
                DemoLine(x0: 0.03, y0: 0.97, x1: 0.5, y1: 0.5, kind: .valley),
                DemoLine(x0: 0.97, y0: 0.97, x1: 0.5, y1: 0.5, kind: .valley),
                DemoLine(x0: 0.25, y0: 0.03, x1: 0.5, y1: 0.25, kind: .mountain),
                DemoLine(x0: 0.75, y0: 0.03, x1: 0.5, y1: 0.25, kind: .valley),
                DemoLine(x0: 0.03, y0: 0.25, x1: 0.25, y1: 0.5, kind: .mountain),
                DemoLine(x0: 0.25, y0: 0.97, x1: 0.5, y1: 0.75, kind: .valley),
                DemoLine(x0: 0.75, y0: 0.97, x1: 0.5, y1: 0.75, kind: .mountain),
                DemoLine(x0: 0.997, y0: 0.25, x1: 0.75, y1: 0.5, kind: .valley),
                DemoLine(x0: 0.25, y0: 0.25, x1: 0.75, y1: 0.75, kind: .flat),
                DemoLine(x0: 0.75, y0: 0.25, x1: 0.25, y1: 0.75, kind: .flat),
            ]
        case "long":
            return boundary + [
                DemoLine(x0: 0.03, y0: 0.03, x1: 0.97, y1: 0.97, kind: .mountain),
                DemoLine(x0: 0.97, y0: 0.03, x1: 0.03, y1: 0.97, kind: .valley),
            ]
        default: // "untitled" / empty square
            return boundary
        }
    }

    /// Pick a demo pattern from a project name (mirrors the seeded reference screenshots).
    static func pattern(forProjectName name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("bird") { return "bird" }
        if lower.contains("crane") { return "crane" }
        if lower.contains("hydrangea") { return "hydrangea" }
        if lower.contains("test") { return "test" }
        if lower.contains("long") { return "long" }
        return "untitled"
    }

    // MARK: OPXC marker data

    private static let markerKey = "ORIPASnapshotDemo"

    /// OPXC bytes for a demo project: a tiny JSON document with the demo pattern marker.
    static func opxcData(pattern: String) -> Data {
        (try? JSONSerialization.data(withJSONObject: [markerKey: pattern],
                                     options: [.sortedKeys])) ?? Data()
    }

    /// Extracts the demo pattern marker from OPXC bytes (nil for real project data).
    static func marker(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pattern = object[markerKey] as? String else {
            return nil
        }
        return pattern
    }

    // MARK: PNG rendering (CoreGraphics — headless-safe)

    static func renderPNG(pattern: String, pixelSize: Int) -> Data? {
        guard let cgImage = renderCGImage(pattern: pattern, pixelSize: pixelSize) else { return nil }
        return OripaImage.pngData(from: cgImage)
    }

    static func renderCGImage(pattern: String, pixelSize: Int) -> CGImage? {
        let size = CGFloat(pixelSize)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: pixelSize,
                                      height: pixelSize,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        // Flip so the normalised Y-down coordinates draw like the CP coordinate system.
        context.translateBy(x: 0, y: size)
        context.scaleBy(x: 1, y: -1)
        let scale = size
        for line in lines(for: pattern) {
            let (color, width): (CGColor, CGFloat) = {
                switch line.kind {
                case .boundary:
                    return (CGColor(red: 0, green: 0, blue: 0, alpha: 1), 2.0)
                case .mountain:
                    return (CGColor(red: 1, green: 0, blue: 0, alpha: 1), 1.4)
                case .valley:
                    return (CGColor(red: 0, green: 0, blue: 1, alpha: 1), 1.4)
                case .flat:
                    return (CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1), 1.0)
                }
            }()
            context.setStrokeColor(color)
            context.setLineWidth(width)
            context.move(to: CGPoint(x: line.x0 * scale, y: line.y0 * scale))
            context.addLine(to: CGPoint(x: line.x1 * scale, y: line.y1 * scale))
            context.strokePath()
        }
        return context.makeImage()
    }

    /// SwiftUI view of a demo pattern (used by the snapshot-only preview renderer).
    static func previewView(pattern: String) -> some View {
        Group {
            if let cgImage = renderCGImage(pattern: pattern, pixelSize: 768) {
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            } else {
                OrTheme.surface
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrTheme.surface)
    }

    // MARK: Seeding

    /// Create a temporary on-disk store with demo projects (thumbnails + marker OPXC files).
    @MainActor
    static func makeApp(projectNames: [String],
                        route: [Route] = [.projects]) -> AppModel {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("oripa-snapshot-\(UUID().uuidString)", isDirectory: true)
        let store = ProjectStore(rootURL: root)
        let now = Date()
        for (index, name) in projectNames.enumerated() {
            let pattern = pattern(forProjectName: name)
            let png = renderPNG(pattern: pattern, pixelSize: 360)
            try? store.write(name: name, opxc: opxcData(pattern: pattern), thumbPNG: png)
            // Distinct modification dates so the sort orders are deterministic/realistic.
            let mtime = now.addingTimeInterval(-Double(index) * 3600 * 6 - 600)
            setModificationDate(store.projectPath(name), mtime)
            setModificationDate(store.thumbPath(name), mtime)
        }
        store.reload()
        let suiteName = "oripa.snapshot.prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let prefs = Preferences(defaults: defaults)
        return AppModel(navigation: route, prefs: prefs, store: store)
    }

    private static func setModificationDate(_ url: URL, _ date: Date) {
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
