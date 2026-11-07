// Headless SwiftUI snapshot renderer — local visual QA without Xcode/simulator.
//
//   swift run ORIPASnapshots [options] [output-directory]
//
// Renders every scenario from ORIPAUI.SnapshotScenarios through SwiftUI's
// ImageRenderer and writes PNGs (plus manifest.json) to <output-directory>
// (default: build-snapshots). Works on a headless macOS machine: ImageRenderer
// draws into an offscreen CGImage, no window server required.
//
// The same tool runs locally (`swift run ORIPASnapshots build-snapshots`) and in
// CI, where the PNGs are uploaded as an artifact for visual review.
//
// Options:
//   -h, --help             show this help and exit
//   -l, --list             list scenario names (no rendering)
//   -o, --out <dir>        output directory (default: build-snapshots)
//   -s, --scenario <name>  render only the named scenario(s); repeatable
//       --scale <n>        rasterisation scale in 1...4 (default: 2)
//
// Exit status: 0 all rendered, 1 rendering failure, 2 bad usage.
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import Darwin
import ORIPAUI

// MARK: - CLI options

private struct SnapshotOptions {
    var outputDirectory = "build-snapshots"
    var scale: CGFloat = 2
    var selectedNames: [String] = []
    var listOnly = false
    var showHelp = false

    static let usage = """
    usage: ORIPASnapshots [options] [output-directory]

    Render ORIPA's SwiftUI screens to PNG without Xcode or a window server.

    Options:
      -h, --help             show this help and exit
      -l, --list             list scenario names and exit (no rendering)
      -o, --out <dir>        output directory (default: build-snapshots)
      -s, --scenario <name>  render only the named scenario(s); can be repeated
          --scale <n>        rasterisation scale, 1...4 (default: 2)

    Output: <dir>/<scenario>.png for every scenario plus <dir>/manifest.json.
    """

    static func parse(_ arguments: [String]) throws -> SnapshotOptions {
        var options = SnapshotOptions()
        var index = 1 // arguments[0] is the executable path
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                options.showHelp = true
                index += 1
            case "-l", "--list":
                options.listOnly = true
                index += 1
            case "-o", "--out", "--output":
                guard index + 1 < arguments.count else {
                    throw SnapshotError("missing value for \(argument)")
                }
                options.outputDirectory = arguments[index + 1]
                index += 2
            case "-s", "--scenario":
                guard index + 1 < arguments.count else {
                    throw SnapshotError("missing value for \(argument)")
                }
                options.selectedNames.append(arguments[index + 1])
                index += 2
            case "--scale":
                guard index + 1 < arguments.count,
                      let value = Double(arguments[index + 1]) else {
                    throw SnapshotError("missing or invalid value for --scale")
                }
                guard value >= 1, value <= 4 else {
                    throw SnapshotError("--scale must be between 1 and 4")
                }
                options.scale = CGFloat(value)
                index += 2
            default:
                if argument.hasPrefix("-") {
                    throw SnapshotError("unknown option: \(argument)")
                }
                options.outputDirectory = argument
                index += 1
            }
        }
        return options
    }
}

// MARK: - Errors / helpers

private struct SnapshotError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

private enum SnapshotOutput {
    /// Lowercase, dash-separated file stem safe on every filesystem.
    static func slugify(_ name: String) -> String {
        var result = ""
        var lastWasDash = false
        for scalar in name.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash && !result.isEmpty {
                result.append("-")
                lastWasDash = true
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        return result.isEmpty ? "snapshot" : result
    }

    static func uniqueFileName(for stem: String, used: inout [String: Int]) -> String {
        if let count = used[stem] {
            used[stem] = count + 1
            return "\(stem)-\(count + 1)"
        }
        used[stem] = 1
        return stem
    }
}

// MARK: - Main

@main
struct SnapshotsMain {
    @MainActor
    static func main() {
        let options: SnapshotOptions
        do {
            options = try SnapshotOptions.parse(CommandLine.arguments)
        } catch {
            fail("\(error)\n\n\(SnapshotOptions.usage)")
        }
        if options.showHelp {
            print(SnapshotOptions.usage)
            exit(0)
        }

        let items = SnapshotCatalog.all()
        guard !items.isEmpty else {
            fail("no snapshot scenarios available (ORIPAUI.SnapshotScenarios returned none)")
        }

        // Optional scenario filter (exact name or slugified file stem).
        var selected = items
        if !options.selectedNames.isEmpty {
            let available = Set(items.flatMap { [$0.name, SnapshotOutput.slugify($0.name)] })
            let missing = options.selectedNames.filter { !available.contains($0) }
            if !missing.isEmpty {
                let list = items.map { "  \($0.name) [\(Int($0.size.width))x\(Int($0.size.height))]" }
                fail("unknown scenario(s): \(missing.joined(separator: ", "))\n" +
                     "available:\n" + list.joined(separator: "\n"))
            }
            selected = items.filter { item in
                options.selectedNames.contains(item.name) ||
                options.selectedNames.contains(SnapshotOutput.slugify(item.name))
            }
        }

        if options.listOnly {
            for item in selected {
                print("\(item.name)\t\(Int(item.size.width))x\(Int(item.size.height))")
            }
            exit(0)
        }

        let outputDirectory = URL(fileURLWithPath: options.outputDirectory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: outputDirectory,
                                                    withIntermediateDirectories: true)
        } catch {
            fail("cannot create output directory \(outputDirectory.path): \(error)")
        }

        print("ORIPA snapshots: \(selected.count) scenario(s) -> \(outputDirectory.path) @\(formatScale(options.scale))x")
        var entries: [SnapshotManifestEntry] = []
        var failures = 0
        var usedFileNames: [String: Int] = [:]
        for item in selected {
            let stem = SnapshotOutput.uniqueFileName(
                for: SnapshotOutput.slugify(item.name), used: &usedFileNames)
            let file = stem + ".png"
            let url = outputDirectory.appendingPathComponent(file)
            let started = Date()
            do {
                let image = try render(item, scale: options.scale)
                try writePNG(image, to: url)
                let elapsed = String(format: "%.2f", Date().timeIntervalSince(started))
                let pixels = "\(Int(item.size.width * options.scale))x\(Int(item.size.height * options.scale))"
                print("  ok   \(item.name) (\(pixels) px, \(elapsed)s) -> \(url.path)")
                entries.append(SnapshotManifestEntry(
                    name: item.name,
                    file: file,
                    width: Int(item.size.width * options.scale),
                    height: Int(item.size.height * options.scale),
                    rendered: true
                ))
            } catch {
                failures += 1
                FileHandle.standardError.write(Data("  FAIL \(item.name): \(error)\n".utf8))
                entries.append(SnapshotManifestEntry(
                    name: item.name,
                    file: file,
                    width: Int(item.size.width * options.scale),
                    height: Int(item.size.height * options.scale),
                    rendered: false
                ))
            }
        }

        let manifest = SnapshotManifest(
            generator: "ORIPASnapshots",
            scale: Double(options.scale),
            scenarios: entries
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest)
                .write(to: outputDirectory.appendingPathComponent("manifest.json"))
        } catch {
            fail("cannot write manifest.json: \(error)")
        }

        if failures > 0 {
            FileHandle.standardError.write(
                Data("snapshots: \(failures) of \(selected.count) scenario(s) failed\n".utf8))
            exit(1)
        }
        print("snapshots: wrote \(entries.count) PNG(s) to \(outputDirectory.path)")
        exit(0)
    }

    /// Rasterisation scale rendered as an integer when possible ("2", not "2.0").
    private static func formatScale(_ scale: CGFloat) -> String {
        if scale == scale.rounded() { return String(Int(scale)) }
        return String(format: "%.1f", Double(scale))
    }

    /// Render a single scenario at `scale` and return the resulting CGImage.
    @MainActor
    private static func render(_ item: SnapshotItem, scale: CGFloat) throws -> CGImage {
        let content = item.view.frame(width: item.size.width, height: item.size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.isOpaque = false
        guard let image = renderer.cgImage else {
            throw SnapshotError("ImageRenderer produced no image " +
                                "(view size \(Int(item.size.width))x\(Int(item.size.height)))")
        }
        return image
    }

    /// Write a PNG file (via ImageIO, independent of AppKit bitmap representations).
    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw SnapshotError("cannot create PNG destination \(url.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw SnapshotError("cannot write PNG \(url.path)")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(2)
    }
}

// MARK: - Manifest

private struct SnapshotManifest: Codable {
    let generator: String
    let scale: Double
    let scenarios: [SnapshotManifestEntry]
}

private struct SnapshotManifestEntry: Codable {
    let name: String
    let file: String
    let width: Int
    let height: Int
    let rendered: Bool
}
