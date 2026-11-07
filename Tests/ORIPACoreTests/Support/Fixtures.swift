// Shared golden-fixture loader for ORIPACore tests.
//
// Golden JSON is generated from the reference JavaScript implementation
// (`oripa-port/src/js`) by the `tools/fixtures/*.js` Node scripts and committed under
// `Fixtures/`. CI never runs Node: it only decodes the committed JSON.
//
// Fixture layout:
//   Fixtures/core/<name>.json    — core-model workstream
//   Fixtures/foldio/<name>.json  — fold-io workstream
//   Fixtures/cases/*.opx|.cp|.opxc — real crease-pattern files (reference corpus)
import Foundation
import XCTest

enum Fixtures {
    /// Repository root computed from this file's location (works for local + CI).
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // ORIPACoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repo root

    static func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    static func data(_ relativePath: String) -> Data {
        guard let data = try? Data(contentsOf: url(relativePath)) else {
            XCTFail("missing fixture: \(relativePath)")
            return Data()
        }
        return data
    }

    static func string(_ relativePath: String) -> String {
        String(data: data(relativePath), encoding: .utf8) ?? ""
    }

    static func decode<T: Decodable>(_ type: T.Type, _ relativePath: String) -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data(relativePath))
        } catch {
            XCTFail("cannot decode fixture \(relativePath): \(error)")
            fatalError("cannot decode fixture \(relativePath): \(error)")
        }
    }

    /// Golden comparison for doubles. The JS reference computes in IEEE-754 doubles,
    /// so most values match exactly; use a tolerance for transcendental functions
    /// (sin/cos/atan2) where Swift and JavaScript may differ in the last ulp.
    static func assertClose(
        _ actual: Double,
        _ expected: Double,
        accuracy: Double = 1e-9,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if actual.isNaN && expected.isNaN { return }
        XCTAssertEqual(actual, expected, accuracy: accuracy, message(), file: file, line: line)
    }

    static func assertClose(
        _ actual: (Double, Double),
        _ expected: (Double, Double),
        accuracy: Double = 1e-9,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertClose(actual.0, expected.0, accuracy: accuracy, message(), file: file, line: line)
        assertClose(actual.1, expected.1, accuracy: accuracy, message(), file: file, line: line)
    }
}
