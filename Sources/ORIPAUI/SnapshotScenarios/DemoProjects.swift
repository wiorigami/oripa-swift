// Demo projects for the headless snapshot scenarios (`swift run ORIPASnapshots`).
//
// The reference screenshots (`tools/ui_harness/ui-projects.html`) seed six projects whose
// thumbnails/preview are drawn by a deterministic `drawCp()` helper: a square boundary plus
// sixteen random red / blue / grey crease lines picked from a fixed point set. This file is
// a line-for-line port of that generator (including the `Math.imul` PRNG) so the snapshot
// thumbnails and the read-only preview show the same line art as the reference screenshots.
//
// The project OPXC files carry a small JSON marker with the demo seed; the snapshot-only
// preview renderer installed by `SnapshotScenarios` reads it (runtime always uses the real
// ui-canvas renderer registered by `ORIPACanvasIntegration.install()`).
import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum DemoProjects {

    // MARK: Reference seed data

    /// The six projects and order of the reference `ui-projects.html` screenshots
    /// (sorted by last modified, descending).
    static let referenceProjectNames = [
        "test-square",
        "crane base",
        "untitled",
        "hydrangea",
        "a-very-long-origami-project-name",
        "untitled-1",
    ]

    /// `ui-projects.html` seeds: `{ name, offset, seed }` with `now = 2026-11-07 09:55:07`.
    /// The reference screenshots were captured from that base time, so fixed dates make the
    /// "Modified: %s" texts pixel-comparable (and the sort order deterministic).
    private static let referenceBaseDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 7
        components.hour = 9
        components.minute = 55
        components.second = 7
        return Calendar.current.date(from: components) ?? Date()
    }()

    /// `{ name: (offset from the reference base, seed) }`.
    private static let referenceSeeds: [String: (offset: TimeInterval, seed: Int)] = [
        "test-square": (12 * 60, 2),
        "crane base": (3 * 3600, 3),
        "untitled": (27 * 3600, 1),
        "hydrangea": (5 * 86400, 7),
        "a-very-long-origami-project-name": (8 * 86400, 9),
        "untitled-1": (30 * 86400, 5),
    ]

    /// Deterministic CP seed for a project name (`seedOf(bytes)` in the harness: project
    /// files are seeded with their own index, the harness maps them explicitly).
    static func seed(forProjectName name: String) -> Int {
        referenceSeeds[name]?.seed ?? 1
    }

    /// Fixed last-modified date for a reference project (falls back to a stable offset for
    /// unknown demo names).
    static func modifiedDate(forProjectName name: String, fallbackIndex: Int = 0) -> Date {
        if let entry = referenceSeeds[name] {
            return referenceBaseDate.addingTimeInterval(-entry.offset)
        }
        return referenceBaseDate.addingTimeInterval(-Double(fallbackIndex + 1) * 3600)
    }

    // MARK: Pattern generator (port of ui-projects.html `drawCp`)

    /// `PATTERN_POINTS` of the reference harness.
    private static let patternPoints: [(x: CGFloat, y: CGFloat)] = [
        (0, 0), (1, 0), (1, 1), (0, 1), (0.5, 0), (1, 0.5), (0.5, 1),
        (0, 0.5), (0.5, 0.5), (0.25, 0.75), (0.75, 0.25), (0.25, 0.25),
        (0.75, 0.75), (0.35, 0.1), (0.1, 0.35),
    ]

    /// `rng(seed)` of the reference harness (`Math.imul` 32-bit PRNG).
    private struct DemoRandom {
        private var state: Int32

        init(seed: Int) {
            // `rng(seed * 7919 + 13)`
            let mixed = seed &* 7919 &+ 13
            state = Int32(truncatingIfNeeded: mixed)
        }

        private static func logicalShiftRight(_ value: Int32, _ amount: UInt32) -> Int32 {
            Int32(bitPattern: UInt32(bitPattern: value) >> amount)
        }

        mutating func next() -> Double {
            // s = (s + 0x6D2B79F5) | 0
            state = state &+ Int32(bitPattern: 0x6D2B79F5)
            // t = Math.imul(s ^ (s >>> 15), 1 | s)
            var t = state ^ DemoRandom.logicalShiftRight(state, 15)
            t = t &* (1 | state)
            // t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
            t = (t &+ ((t ^ DemoRandom.logicalShiftRight(t, 7)) &* (61 | t))) ^ t
            // ((t ^ (t >>> 14)) >>> 0) / 4294967296
            let output = UInt32(bitPattern: t ^ DemoRandom.logicalShiftRight(t, 14))
            return Double(output) / 4_294_967_296.0
        }
    }

    private static let creaseColors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (1, 0, 0),       // mountain / red
        (0, 0, 1),       // valley / blue
        (0.5, 0.5, 0.5)  // flat / grey
    ]

    /// `drawCp(canvasW, canvasH, seed)`: white canvas, a 92 %-sized square boundary and
    /// sixteen pseudo-random crease lines, exactly like the reference harness.
    static func renderCGImage(seed: Int, pixelSize: Int) -> CGImage? {
        let size = max(1, pixelSize)
        // sRGB (not DeviceRGB): the untagged device space on macOS is the display profile,
        // which shifted the pure red crease lines to orange when the snapshot was exported.
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: size,
                                      height: size,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        let canvas = CGFloat(size)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
        // Flip so normalised Y-down coordinates draw like the HTML canvas.
        context.translateBy(x: 0, y: canvas)
        context.scaleBy(x: 1, y: -1)

        let square = canvas * 0.92
        let origin = (canvas - square) / 2
        func X(_ u: CGFloat) -> CGFloat { origin + u * square }
        func Y(_ v: CGFloat) -> CGFloat { origin + v * square }

        var random = DemoRandom(seed: seed)
        context.setLineCap(.round)
        for index in 0..<16 {
            let a = patternPoints[Int(random.next() * Double(patternPoints.count))]
            let b = patternPoints[Int(random.next() * Double(patternPoints.count))]
            if a.x == b.x && a.y == b.y { continue }
            let color = creaseColors[index % creaseColors.count]
            context.setStrokeColor(CGColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: 1))
            context.setLineWidth(max(1.2, square * (index % 3 == 0 ? 0.007 : 0.004)))
            context.beginPath()
            context.move(to: CGPoint(x: X(a.x), y: Y(a.y)))
            context.addLine(to: CGPoint(x: X(b.x), y: Y(b.y)))
            context.strokePath()
        }
        // Boundary square, black, `max(1.4, size * 0.006)`.
        context.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(max(1.4, square * 0.006))
        context.stroke(CGRect(x: X(0), y: Y(0), width: square, height: square))

        return context.makeImage()
    }

    static func renderPNG(seed: Int, pixelSize: Int) -> Data? {
        guard let cgImage = renderCGImage(seed: seed, pixelSize: pixelSize) else { return nil }
        return OripaImage.pngData(from: cgImage)
    }

    // MARK: OPXC marker data

    private static let markerKey = "ORIPASnapshotSeed"

    /// OPXC bytes for a demo project: a tiny JSON document with the demo seed marker.
    static func opxcData(seed: Int) -> Data {
        (try? JSONSerialization.data(withJSONObject: [markerKey: seed],
                                     options: [.sortedKeys])) ?? Data()
    }

    /// Extracts the demo seed from OPXC bytes (nil for real project data).
    static func seed(from data: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let seed = object[markerKey] as? Int { return seed }
        if let seed = object[markerKey] as? NSNumber { return seed.intValue }
        return nil
    }

    // MARK: Preview view

    /// Read-only preview of a demo project: `drawCp(viewportWidth, viewportHeight, seed)`
    /// fills the whole screen with the 92 % square centred (the CP is not scaled to a
    /// separate frame in the reference — the PreviewRenderer draws it into the viewport).
    static func previewView(seed: Int) -> some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            if let cgImage = renderCGImage(seed: seed, pixelSize: 1000) {
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: side, height: side)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrTheme.surface)
    }

    // MARK: Seeding

    /// Create a temporary on-disk store with demo projects (thumbnails + marker OPXC files).
    @MainActor
    static func makeApp(projectNames: [String], route: [Route] = [.projects]) -> AppModel {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("oripa-snapshot-\(UUID().uuidString)", isDirectory: true)
        let store = ProjectStore(rootURL: root)
        for (index, name) in projectNames.enumerated() {
            let seed = seed(forProjectName: name)
            let png = renderPNG(seed: seed, pixelSize: 360)
            try? store.write(name: name, opxc: opxcData(seed: seed), thumbPNG: png)
            // Fixed reference mtimes so the "Modified:" texts and sort orders match the
            // reference screenshots exactly.
            let mtime = modifiedDate(forProjectName: name, fallbackIndex: index)
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
