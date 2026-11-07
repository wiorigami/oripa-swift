// Minimal hermetic test harness.
//
// Why not XCTest: the development Mac only has Command Line Tools, whose Swift
// toolchain does not ship the XCTest/Testing modules. A plain executable target runs
// the exact same assertions locally and in GitHub Actions without any test framework,
// which keeps golden-fixture verification reproducible everywhere.
//
// Suite owners (CoreModel, FoldIO) expose `static var all: [TestSuite]`; `main.swift`
// runs every registered suite and exits non-zero on failure.
import Foundation

public struct TestSuite {
    public let name: String
    public let body: (TestHarness) throws -> Void

    public init(_ name: String, _ body: @escaping (TestHarness) throws -> Void) {
        self.name = name
        self.body = body
    }
}

public final class TestHarness {
    public private(set) var checks = 0
    public private(set) var failures: [String] = []
    public private(set) var suitesRun = 0

    private var currentSuite = "?"

    public init() {}

    /// Runs one suite, catching thrown errors as a single failure.
    public func run(_ suite: TestSuite) {
        currentSuite = suite.name
        suitesRun += 1
        do {
            try suite.body(self)
        } catch {
            record("suite threw: \(error)", file: nil, line: nil)
        }
    }

    // MARK: - Assertions

    public func expect(
        _ condition: Bool,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checks += 1
        if !condition {
            record(message(), file: file, line: line)
        }
    }

    public func expectEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checks += 1
        if actual != expected {
            let m = message()
            let suffix = m.isEmpty ? "" : " — \(m)"
            record("expected \(expected), got \(actual)\(suffix)", file: file, line: line)
        }
    }

    public func expectNotEqual<T: Equatable>(
        _ actual: T,
        _ unexpected: T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checks += 1
        if actual == unexpected {
            record("did not expect \(unexpected)", file: file, line: line)
        }
    }

    public func expectNil<T>(
        _ value: T?,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checks += 1
        if value != nil {
            record("expected nil, got \(String(describing: value))", file: file, line: line)
        }
    }

    public func expectNotNil<T>(
        _ value: T?,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T? {
        checks += 1
        if value == nil {
            record("expected non-nil", file: file, line: line)
        }
        return value
    }

    /// Golden comparison for doubles. The JS reference computes IEEE-754 doubles, so most
    /// values match exactly; transcendental functions (sin/cos/atan2) may differ in the
    /// last ulp, hence the tolerance parameter.
    public func expectClose(
        _ actual: Double,
        _ expected: Double,
        accuracy: Double = 1e-9,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checks += 1
        if actual.isNaN && expected.isNaN { return }
        if abs(actual - expected) > accuracy {
            let m = message()
            let suffix = m.isEmpty ? "" : " — \(m)"
            record("expected \(expected) ± \(accuracy), got \(actual)\(suffix)", file: file, line: line)
        }
    }

    public func expectClose(
        _ actual: (Double, Double),
        _ expected: (Double, Double),
        accuracy: Double = 1e-9,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        expectClose(actual.0, expected.0, accuracy: accuracy, message(), file: file, line: line)
        expectClose(actual.1, expected.1, accuracy: accuracy, message(), file: file, line: line)
    }

    public func fail(
        _ message: @autoclosure () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checks += 1
        record(message(), file: file, line: line)
    }

    // MARK: - Reporting

    public func summary() -> String {
        if failures.isEmpty {
            return "PASS \(suitesRun) suites, \(checks) checks, 0 failures"
        }
        var out = "FAIL \(suitesRun) suites, \(checks) checks, \(failures.count) failures\n"
        for f in failures.prefix(200) { out += "  - \(f)\n" }
        if failures.count > 200 { out += "  ... \(failures.count - 200) more\n" }
        return out
    }

    private func record(_ message: String, file: StaticString?, line: UInt?) {
        var location = currentSuite
        if let file {
            let path = "\(file)"
            let base = path.split(separator: "/").last.map(String.init) ?? path
            if let line { location += ":\(base):\(line)" }
            else { location += ":\(base)" }
        }
        failures.append("[\(location)] \(message)")
    }
}
