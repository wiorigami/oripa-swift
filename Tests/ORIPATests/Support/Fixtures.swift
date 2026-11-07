// Shared golden-fixture loader for ORIPACore tests.
//
// Golden JSON is generated from the reference JavaScript implementation
// (`oripa-port/src/js`) by the `tools/fixtures/*.js` Node scripts and committed under
// `Fixtures/`. CI never runs Node: it only decodes the committed JSON.
//
// Fixture layout:
//   Fixtures/core/<name>.json     — core-model workstream
//   Fixtures/foldio/<name>.json   — fold-io workstream
//   Fixtures/cases/*.opx|.cp|.opxc — real crease-pattern files (reference corpus)
//
// Tests live in a plain executable target (Tests/ORIPATests) because this Mac's
// Command Line Tools toolchain has no XCTest module — see TestHarness.swift.
import Foundation

enum Fixtures {
    /// Repository root computed from this file's location (works locally + CI).
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // ORIPATests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repo root

    static func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: url(relativePath))
    }

    static func string(_ relativePath: String) throws -> String {
        try String(contentsOf: url(relativePath), encoding: .utf8)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ relativePath: String) throws -> T {
        try JSONDecoder().decode(T.self, from: data(relativePath))
    }

    /// All files in a fixture directory with the given suffix (e.g. ".cp" case files).
    static func files(in relativeDirectory: String, suffixes: [String]? = nil) -> [URL] {
        let dir = url(relativeDirectory)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }
        return entries.sorted { $0.lastPathComponent < $1.lastPathComponent }.filter { url in
            guard let suffixes else { return true }
            return suffixes.contains { url.pathExtension.lowercased() == $0.lowercased() }
        }
    }
}
