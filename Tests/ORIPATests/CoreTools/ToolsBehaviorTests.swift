// Behaviour checks that are easier to state directly than through the golden scenarios:
// tool-type/batch tables, `getNew()` lifecycle, StateMachineManager delegation/identity,
// nil-context safety (the JS port tolerates a missing Android context; Swift uses `nil`) and
// the optional-safe manager behaviour.
import Foundation
import ORIPACore

enum ToolsBehaviorTests {
    static var all: [TestSuite] {
        [
            TestSuite("CoreToolsBehavior") { harness in
                try run(harness)
            },
        ]
    }

    /// Reference class name -> (tool type, hasBatchLineOperation, hasBatchPointOperation).
    private static let machineTable: [(String, CpToolType, Bool, Bool)] = [
        ("AddAngleBisectorSM", CpToolType.ADD_ANGLE_BISECTOR, false, false),
        ("AddLineExtensionSM", CpToolType.ADD_LINE_EXTENSION, false, false),
        ("AddLineSM", CpToolType.ADD_LINE, false, false),
        ("AddMirroredLinesSM", CpToolType.ADD_MIRRORED_LINES, true, false),
        ("AddPerpendicularBisectorSM", CpToolType.ADD_PERPENDICULAR_BISECTOR, false, false),
        ("AddPerpendicularSegmentSM", CpToolType.ADD_PERPENDICULAR_SEGMENT, false, false),
        ("AddSegmentByValueDrawLineSM", CpToolType.ADD_SEGMENT_BY_VALUE, false, false),
        ("AddSegmentByValueGetAngleSM", CpToolType.ADD_SEGMENT_BY_VALUE, false, false),
        ("AddSegmentByValueGetLengthSM", CpToolType.ADD_SEGMENT_BY_VALUE, false, false),
        ("AddSegmentSM", CpToolType.ADD_SEGMENT, false, false),
        ("AddSymmetricalSegmentSM", CpToolType.ADD_SYMMETRICAL_SEGMENT, false, false),
        ("AddTriangleIncenterSM", CpToolType.ADD_TRIANGLE_INCENTER, false, false),
        ("ChangeLineSM", CpToolType.CHANGE_LINE, true, false),
        ("DeleteLineSM", CpToolType.DELETE_LINE, true, false),
        ("DeleteVertexSM", CpToolType.DELETE_VERTEX, false, true),
        ("SelectLineSM", CpToolType.SELECT_LINE, true, false),
    ]

    private static func line(_ cp: CreasePattern,
                             _ x1: Double, _ y1: Double,
                             _ x2: Double, _ y2: Double,
                             _ type: LineType = .mountain) {
        _ = cp.addLineCheckNoException(
            OriPoint(x1, y1), OriPoint(x2, y2), type
        )
    }

    private static func transition(_ sm: CpStateMachine, _ cp: CreasePattern,
                                   x: Double, y: Double) -> Int {
        sm.doTransition(
            creasePattern: cp, snap: false, pointDouble: PointDouble(x, y), radius: 5.0
        )
    }

    private static func run(_ harness: TestHarness) throws {
        // 1. Machine table: tool type, batch capabilities, getNew() lifecycle (JS suite's
        //    "complex construction tools construct + react to snapping" + per-tool checks).
        for (name, toolType, batchLine, batchPoint) in machineTable {
            let sm = ToolsTestSupport.makeMachine(name, true)
            harness.expectEqual(sm.getToolType(), toolType.rawValue, "\(name): tool type")
            harness.expectEqual(
                sm.hasBatchLineOperation(), batchLine, "\(name): hasBatchLineOperation"
            )
            harness.expectEqual(
                sm.hasBatchPointOperation(), batchPoint, "\(name): hasBatchPointOperation"
            )
            harness.expectEqual(
                sm.getDirectSelectionEnabled(), true, "\(name): direct selection enabled"
            )
            let fresh = sm.getNew()
            harness.expect(fresh !== sm, "\(name): getNew() creates a new instance")
            harness.expect(
                String(describing: type(of: fresh)) == name,
                "\(name): getNew() keeps concrete type (got \(String(describing: type(of: fresh))))"
            )
            harness.expectEqual(
                fresh.getToolType(), toolType.rawValue, "\(name): getNew() keeps tool type"
            )
        }

        // Direct selection flag is passed through the constructor.
        let indirectSegment = AddSegmentSM(false)
        harness.expectEqual(
            indirectSegment.getDirectSelectionEnabled(), false, "AddSegmentSM(false): direct flag"
        )
        harness.expectEqual(
            indirectSegment.getState().pointsPicked.size(), 0, "fresh machine: no picked points"
        )
        harness.expectEqual(
            indirectSegment.getState().linesPicked.size(), 0, "fresh machine: no picked lines"
        )
        harness.expectNil(indirectSegment.getState().tempPointPicked, "fresh machine: temp point")
        harness.expectNil(indirectSegment.getState().tempLinePicked, "fresh machine: temp line")

        // 2. StateMachineManager identity + delegation.
        let manager = StateMachineManager()
        let segment = AddSegmentSM(true)
        manager.newMachine(segment)
        harness.expect(manager.getCurrentMachine() === segment, "manager: current machine identity")
        harness.expect(manager.getState() === segment.getState(), "manager: state identity")
        harness.expectEqual(manager.getToolType(), CpToolType.ADD_SEGMENT.rawValue,
                            "manager: delegated tool type")
        harness.expectEqual(manager.getDirectSelectionEnabled(), true,
                            "manager: delegated direct selection")
        harness.expectEqual(manager.hasBatchLineOperation(), false,
                            "manager: delegated batch line flag")
        let cpForManager = CreasePattern()
        line(cpForManager, 0, 0, 100, 0)
        line(cpForManager, 0, 100, 100, 100)
        harness.expectEqual(
            manager.doTransition(
                creasePattern: cpForManager, snap: false,
                pointDouble: PointDouble(1, 1), radius: 5.0
            ),
            CpTransitionResult.CHANGED_POINTS.rawValue,
            "manager: delegated transition"
        )
        harness.expectEqual(
            manager.doLongTransition(
                creasePattern: cpForManager, z: false,
                pointDouble: PointDouble(1, 1), radius: 5.0
            ),
            CpTransitionResult.NO_CHANGE.rawValue,
            "manager: delegated long transition"
        )
        manager.resetMachine()
        harness.expect(manager.getCurrentMachine() !== segment, "manager: resetMachine replaces")
        harness.expect(manager.getCurrentMachine() is AddSegmentSM, "manager: resetMachine type")
        harness.expectEqual(manager.getToolType(), CpToolType.ADD_SEGMENT.rawValue,
                            "manager: resetMachine keeps tool type")

        // 3. Fresh manager is nil-safe (the JS reference would throw on a null dereference;
        //    the native port degrades to NO_CHANGE/empty results, never crashes).
        let emptyManager = StateMachineManager()
        harness.expectNil(emptyManager.getCurrentMachine(), "empty manager: no current machine")
        harness.expectEqual(emptyManager.getToolType(), -1, "empty manager: sentinel tool type")
        harness.expectEqual(emptyManager.getDirectSelectionEnabled(), false,
                            "empty manager: direct selection fallback")
        harness.expectEqual(emptyManager.hasBatchLineOperation(), false,
                            "empty manager: batch line fallback")
        harness.expectEqual(emptyManager.hasBatchPointOperation(), false,
                            "empty manager: batch point fallback")
        harness.expectEqual(
            emptyManager.doLongTransition(
                creasePattern: cpForManager, z: false,
                pointDouble: PointDouble(0, 0), radius: 5.0
            ),
            CpTransitionResult.NO_CHANGE.rawValue,
            "empty manager: long transition fallback"
        )
        harness.expect(
            emptyManager.finish(context: nil, cp: cpForManager).isEmpty(),
            "empty manager: finish returns empty group"
        )
        harness.expect(
            emptyManager.doBatchLineOperation(
                context: nil, cp: cpForManager,
                start: OriPoint(-1, -1), end: OriPoint(101, 101)
            ).isEmpty(),
            "empty manager: batch line returns empty group"
        )
        harness.expect(
            emptyManager.doBatchPointOperation(
                context: nil, cp: cpForManager,
                start: OriPoint(-1, -1), end: OriPoint(101, 101)
            ).isEmpty(),
            "empty manager: batch point returns empty group"
        )

        // 4. CpContext mock adapter round-trip (what ui-canvas implements over Preferences).
        let context = MockCpContext(nil)
        harness.expectEqual(context.getPref("missing.key", 42), 42,
                            "context: pref default")
        context.prefs["PaintCpFragment.color"] = 7
        harness.expectEqual(context.getPref("PaintCpFragment.color", 0), 7,
                            "context: pref read")
        context.setByValueButtonAngleDegText(-45.0)
        context.setByValueButtonLengthText(12.5)
        harness.expectEqual(context.getByValueButtonAngleDegText(), -45.0,
                            "context: angle setter/getter")
        harness.expectEqual(context.getByValueButtonLengthText(), 12.5,
                            "context: length setter/getter")

        // 5. Nil-context safety for the pref-driven machines (nil => Android defaults).
        let changeCp = CreasePattern()
        line(changeCp, 0, 0, 100, 0, .mountain)
        let changeSM = ChangeLineSM(true)
        harness.expectEqual(transition(changeSM, changeCp, x: 50, y: 1),
                            CpTransitionResult.FINISHED.rawValue, "ChangeLineSM: pick line")
        let unchanged = changeSM.finish(context: nil, cp: changeCp)
        harness.expect(unchanged.isEmpty(), "ChangeLineSM: nil context defaults to no change")
        harness.expectEqual(changeCp.lineMVFB.getAllLines()[0].type(), .mountain,
                            "ChangeLineSM: line type preserved")

        let deleteCp = CreasePattern()
        line(deleteCp, 0, 0, 100, 0, .mountain)
        let deleteSM = DeleteLineSM(true)
        harness.expectEqual(transition(deleteSM, deleteCp, x: 50, y: 1),
                            CpTransitionResult.FINISHED.rawValue, "DeleteLineSM: pick line")
        let deleteGroup = deleteSM.finish(context: nil, cp: deleteCp)
        harness.expect(!deleteGroup.isEmpty(), "DeleteLineSM: nil context deletes any line")
        harness.expectEqual(deleteCp.lineMVFB.size(), 0, "DeleteLineSM: line removed")

        // 6. Nil-context safety for the by-value machines (no paint fragment => no-op/0.0).
        let byValueCp = CreasePattern()
        line(byValueCp, 0, 0, 100, 0, .mountain)
        let getAngleSM = AddSegmentByValueGetAngleSM(true)
        _ = transition(getAngleSM, byValueCp, x: 1, y: 1)
        _ = transition(getAngleSM, byValueCp, x: 99, y: 1)
        harness.expect(
            getAngleSM.finish(context: nil, cp: byValueCp).isEmpty(),
            "GetAngle: nil context returns empty group"
        )
        let getLengthSM = AddSegmentByValueGetLengthSM(true)
        _ = transition(getLengthSM, byValueCp, x: 1, y: 1)
        _ = transition(getLengthSM, byValueCp, x: 99, y: 1)
        harness.expect(
            getLengthSM.finish(context: nil, cp: byValueCp).isEmpty(),
            "GetLength: nil context returns empty group"
        )

        // 7. SelectLineSM overflow actions on an empty selection.
        let selectSM = SelectLineSM(true)
        let selectCp = CreasePattern()
        line(selectCp, 0, 0, 100, 0)
        harness.expect(selectSM.deleteSelected(selectCp).isEmpty(),
                       "SelectLineSM: deleteSelected with empty selection")
        selectSM.deselectAll()
        harness.expectEqual(selectSM.getState().linesPicked.size(), 0,
                            "SelectLineSM: deselectAll keeps selection empty")
        harness.expect(selectSM.finish(context: nil, cp: selectCp).isEmpty(),
                       "SelectLineSM: finish returns empty group")

        // 8. AddMirroredLinesSM: long-transition without a line under the finger + nil-safe
        //    finish before an axis was picked, and batch selection into the picked set.
        let mirrorSM = AddMirroredLinesSM(true)
        let mirrorCp = CreasePattern()
        line(mirrorCp, 0, 10, 50, 10, .mountain)
        harness.expectEqual(
            mirrorSM.doLongTransition(
                creasePattern: mirrorCp, z: false,
                pointDouble: PointDouble(500, 500), radius: 5.0
            ),
            CpTransitionResult.NO_CHANGE.rawValue,
            "AddMirroredLinesSM: no axis under the finger"
        )
        harness.expect(mirrorSM.finish(context: nil, cp: mirrorCp).isEmpty(),
                       "AddMirroredLinesSM: finish without axis is empty")
        let batchGroup = mirrorSM.doBatchLineOperation(
            context: nil, cp: mirrorCp,
            start: OriPoint(-1, 9), end: OriPoint(51, 11)
        )
        harness.expect(batchGroup.isEmpty(), "AddMirroredLinesSM: batch select records no history")
        harness.expectEqual(mirrorSM.getState().linesPicked.size(), 1,
                            "AddMirroredLinesSM: batch selection added the line")

        // 9. Manager batch delegation through a selecting machine.
        let batchManager = StateMachineManager()
        batchManager.newMachine(SelectLineSM(true))
        let batchCp = CreasePattern()
        line(batchCp, 0, 0, 100, 0)
        line(batchCp, 0, 100, 100, 100)
        _ = batchManager.doBatchLineOperation(
            context: nil, cp: batchCp,
            start: OriPoint(-1, -1), end: OriPoint(101, 101)
        )
        harness.expectEqual(batchManager.getState().linesPicked.size(), 2,
                            "manager: batch delegation selected both lines")
        harness.expect(batchManager.finish(context: nil, cp: batchCp).isEmpty(),
                       "manager: finish through delegated SelectLineSM")
    }
}
