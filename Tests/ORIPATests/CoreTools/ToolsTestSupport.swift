// Shared support for the CoreTools suites: mock `CpContext`, machine factory and golden
// assertions (line-set comparison is order-independent and tolerant to the last-ulp
// differences between V8 and Swift `sin`/`cos`).
import Foundation
import ORIPACore

/// Mock of the editor's `CpContext` adapter: Android-preference int reads + the
/// "Segment by Value" angle/length fields, exactly like the JS test's mock context object.
final class MockCpContext: CpContext {
    var prefs: [String: Int]
    var angle: Double
    var length: Double

    init(_ spec: ToolsFixture.ContextSpec?) {
        self.prefs = spec?.pref ?? [:]
        self.angle = spec?.angle ?? 0.0
        self.length = spec?.length ?? 0.0
    }

    func getPref(_ key: String, _ defaultValue: Int) -> Int {
        prefs[key] ?? defaultValue
    }

    func getByValueButtonAngleDegText() -> Double { angle }
    func getByValueButtonLengthText() -> Double { length }
    func setByValueButtonAngleDegText(_ value: Double) { angle = value }
    func setByValueButtonLengthText(_ value: Double) { length = value }
}

enum ToolsTestSupport {
    static let accuracy = 1e-9

    /// Creates a concrete tool machine by the reference class name.
    static func makeMachine(_ name: String, _ directSelectionEnabled: Bool) -> CpStateMachine {
        switch name {
        case "AddAngleBisectorSM": return AddAngleBisectorSM(directSelectionEnabled)
        case "AddLineExtensionSM": return AddLineExtensionSM(directSelectionEnabled)
        case "AddLineSM": return AddLineSM(directSelectionEnabled)
        case "AddMirroredLinesSM": return AddMirroredLinesSM(directSelectionEnabled)
        case "AddPerpendicularBisectorSM": return AddPerpendicularBisectorSM(directSelectionEnabled)
        case "AddPerpendicularSegmentSM": return AddPerpendicularSegmentSM(directSelectionEnabled)
        case "AddSegmentByValueDrawLineSM": return AddSegmentByValueDrawLineSM(directSelectionEnabled)
        case "AddSegmentByValueGetAngleSM": return AddSegmentByValueGetAngleSM(directSelectionEnabled)
        case "AddSegmentByValueGetLengthSM": return AddSegmentByValueGetLengthSM(directSelectionEnabled)
        case "AddSegmentSM": return AddSegmentSM(directSelectionEnabled)
        case "AddSymmetricalSegmentSM": return AddSymmetricalSegmentSM(directSelectionEnabled)
        case "AddTriangleIncenterSM": return AddTriangleIncenterSM(directSelectionEnabled)
        case "ChangeLineSM": return ChangeLineSM(directSelectionEnabled)
        case "DeleteLineSM": return DeleteLineSM(directSelectionEnabled)
        case "DeleteVertexSM": return DeleteVertexSM(directSelectionEnabled)
        case "SelectLineSM": return SelectLineSM(directSelectionEnabled)
        default:
            preconditionFailure("unknown state machine \(name)")
        }
    }

    static func makeContext(_ spec: ToolsFixture.ContextSpec?) -> MockCpContext? {
        guard let spec else { return nil }
        return MockCpContext(spec)
    }

    static func point(_ values: [Double]) -> PointDouble {
        PointDouble(values[0], values[1])
    }

    static func oriPoint(_ values: [Double]) -> OriPoint {
        OriPoint(values[0], values[1])
    }

    static func pointArray(_ pointDouble: PointDouble) -> [Double] {
        [pointDouble.x, pointDouble.y]
    }

    static func lineArray(_ oriLine: OriLine) -> [Double] {
        [oriLine.start.x, oriLine.start.y, oriLine.end.x, oriLine.end.y,
         Double(oriLine.type().rawValue)]
    }

    // MARK: - Golden assertions

    static func assertCP(
        _ harness: TestHarness,
        _ cp: CreasePattern,
        _ expected: ToolsFixture.CPSnapshot,
        _ label: String
    ) {
        harness.expectEqual(cp.lineMVFB.size(), expected.lineCount, "\(label): line count")
        harness.expectEqual(cp.pointMVFB.size(), expected.pointCount, "\(label): point count")
        assertLineSets(
            harness,
            cp.lineMVFB.getAllLines().map(lineArray),
            expected.lines,
            "\(label): lines"
        )
    }

    /// Order-independent multiset comparison of `[x1,y1,x2,y2,type]` lines.
    static func assertLineSets(
        _ harness: TestHarness,
        _ actual: [[Double]],
        _ expected: [[Double]],
        _ label: String
    ) {
        harness.expectEqual(actual.count, expected.count, "\(label): count")
        var used = [Bool](repeating: false, count: actual.count)
        var matched = 0
        for expectedLine in expected {
            if let index = actual.indices.first(where: { !used[$0] && close(actual[$0], expectedLine) }) {
                used[index] = true
                matched += 1
            } else {
                harness.expect(
                    false,
                    "\(label): missing \(expectedLine) in \(actual)"
                )
            }
        }
        if matched == expected.count {
            harness.expect(true, "\(label): all lines matched")
        }
    }

    static func assertState(
        _ harness: TestHarness,
        _ state: CpState,
        _ expected: ToolsFixture.StateSnapshot,
        _ label: String
    ) {
        let pointsPicked = state.pointsPicked.toArray()
        harness.expectEqual(
            pointsPicked.count, expected.pointsPicked.count, "\(label): pointsPicked count"
        )
        for index in 0..<min(pointsPicked.count, expected.pointsPicked.count) {
            harness.expectClose(
                pointsPicked[index].x, expected.pointsPicked[index][0], accuracy: accuracy,
                "\(label): pointsPicked[\(index)].x"
            )
            harness.expectClose(
                pointsPicked[index].y, expected.pointsPicked[index][1], accuracy: accuracy,
                "\(label): pointsPicked[\(index)].y"
            )
        }
        assertLineSets(
            harness,
            state.linesPicked.values().map(lineArray),
            expected.linesPicked,
            "\(label): linesPicked"
        )
        if let tempPoint = expected.tempPointPicked {
            if let picked = state.tempPointPicked {
                harness.expectClose(picked.x, tempPoint[0], accuracy: accuracy, "\(label): tempPoint.x")
                harness.expectClose(picked.y, tempPoint[1], accuracy: accuracy, "\(label): tempPoint.y")
            } else {
                harness.expect(false, "\(label): expected tempPointPicked \(tempPoint), got nil")
            }
        } else {
            harness.expectNil(state.tempPointPicked, "\(label): tempPointPicked should be nil")
        }
        if let tempLine = expected.tempLinePicked {
            if let picked = state.tempLinePicked {
                harness.expectClose(
                    picked.start.x, tempLine[0], accuracy: accuracy, "\(label): tempLine.start.x"
                )
                harness.expectClose(
                    picked.start.y, tempLine[1], accuracy: accuracy, "\(label): tempLine.start.y"
                )
                harness.expectClose(
                    picked.end.x, tempLine[2], accuracy: accuracy, "\(label): tempLine.end.x"
                )
                harness.expectClose(
                    picked.end.y, tempLine[3], accuracy: accuracy, "\(label): tempLine.end.y"
                )
            } else {
                harness.expect(false, "\(label): expected tempLinePicked \(tempLine), got nil")
            }
        } else {
            harness.expectNil(state.tempLinePicked, "\(label): tempLinePicked should be nil")
        }
    }

    static func assertGroup(
        _ harness: TestHarness,
        _ group: HistoryGroup,
        _ expected: ToolsFixture.GroupSnapshot,
        _ label: String
    ) {
        harness.expectEqual(group.isEmpty(), expected.isEmpty, "\(label): group isEmpty")
        harness.expectEqual(
            group.historyItems.count, expected.historyItems, "\(label): history item count"
        )
    }

    /// Asserts whatever flags the fixture recorded for `getNew()` / `newMachine` / `resetMachine`.
    static func assertFlags(
        _ harness: TestHarness,
        _ expected: ToolsFixture.Expect,
        _ label: String,
        toolType: () -> Int,
        directSelectionEnabled: () -> Bool,
        hasBatchLineOperation: () -> Bool,
        hasBatchPointOperation: () -> Bool
    ) {
        if let expectedToolType = expected.toolType {
            harness.expectEqual(toolType(), expectedToolType, "\(label): toolType")
        }
        if let expectedDirect = expected.directSelectionEnabled {
            harness.expectEqual(
                directSelectionEnabled(), expectedDirect, "\(label): directSelectionEnabled"
            )
        }
        if let expectedBatchLine = expected.hasBatchLineOperation {
            harness.expectEqual(
                hasBatchLineOperation(), expectedBatchLine, "\(label): hasBatchLineOperation"
            )
        }
        if let expectedBatchPoint = expected.hasBatchPointOperation {
            harness.expectEqual(
                hasBatchPointOperation(), expectedBatchPoint, "\(label): hasBatchPointOperation"
            )
        }
    }

    static func close(_ a: [Double], _ b: [Double]) -> Bool {
        guard a.count == b.count else { return false }
        for index in 0..<a.count where abs(a[index] - b[index]) > accuracy {
            return false
        }
        return true
    }
}
