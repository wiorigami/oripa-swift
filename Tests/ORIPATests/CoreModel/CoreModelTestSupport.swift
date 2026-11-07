// Shared helpers for the core-model golden tests.
import Foundation
import ORIPACore

enum CoreModelJSON {
    static func oriPoint(_ values: [Double]) -> OriPoint {
        OriPoint(values[0], values[1])
    }

    static func pointDouble(_ values: [Double]) -> PointDouble {
        PointDouble(values[0], values[1])
    }

    static func line(_ values: [Double]) -> OriLine {
        OriLine(
            OriPoint(values[0], values[1]),
            OriPoint(values[2], values[3]),
            LineType(rawValue: Int(values[4])) ?? .undefined
        )
    }

    static func lineValues(_ line: OriLine) -> [Double] {
        [line.start.x, line.start.y, line.end.x, line.end.y, Double(line.typeValue)]
    }

    static func pointValues(_ point: PointDouble) -> [Double] {
        [point.x, point.y]
    }

    static func sortedLineValues(_ lines: [OriLine]) -> [[Double]] {
        lines.map(lineValues).sorted { lhs, rhs in
            for index in 0..<4 where lhs[index] != rhs[index] {
                return lhs[index] < rhs[index]
            }
            return lhs[4] < rhs[4]
        }
    }

    static func buildCreasePattern(fromLines lines: [[Double]]) -> CreasePattern {
        let creasePattern = CreasePattern()
        for values in lines {
            creasePattern.addLineNoCheck(line(values))
        }
        return creasePattern
    }
}

func expectCloseArray(
    _ harness: TestHarness,
    _ actual: [Double],
    _ expected: [Double],
    accuracy: Double = 1e-9,
    _ message: @autoclosure () -> String = ""
) {
    let label = message()
    harness.expectEqual(actual.count, expected.count, "count \(label)")
    for index in 0..<min(actual.count, expected.count) {
        harness.expectClose(actual[index], expected[index], accuracy: accuracy, "\(label)[\(index)]")
    }
}

func expectEqualArray<T: Equatable>(
    _ harness: TestHarness,
    _ actual: [T],
    _ expected: [T],
    _ message: @autoclosure () -> String = ""
) {
    let label = message()
    harness.expectEqual(actual.count, expected.count, "count \(label)")
    for index in 0..<min(actual.count, expected.count) {
        harness.expectEqual(actual[index], expected[index], "\(label)[\(index)]")
    }
}

func expectEqualMatrix(
    _ harness: TestHarness,
    _ actual: [Double],
    _ expected: [Double],
    accuracy: Double = 1e-12,
    _ message: @autoclosure () -> String = ""
) {
    let label = message()
    harness.expectEqual(actual.count, expected.count, "count \(label)")
    for index in 0..<min(actual.count, expected.count) {
        harness.expectClose(actual[index], expected[index], accuracy: accuracy, "\(label)[\(index)]")
    }
}

func boolValue(_ value: Bool) -> Int { value ? 1 : 0 }

func doesThrow(_ body: () throws -> Void) -> Bool {
    do {
        try body()
        return false
    } catch {
        return true
    }
}
