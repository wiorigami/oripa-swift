// Golden constants from the reference JS (Fixtures/tools/tools.json -> `constants`).
//
// Checks the exact numeric Android/Java constants: `CpToolType`, `CpTransitionResult`,
// `CpEvent`, the ChangeLineSM/DeleteLineSM `R.id.*` values used as preference values, and the
// SharedPreferences key strings (identical to `PaintCpFragment`'s).
import Foundation
import ORIPACore

enum ToolsConstantsTests {
    static var all: [TestSuite] {
        [
            TestSuite("CoreToolsConstants") { harness in
                try run(harness)
            },
        ]
    }

    private static let toolTypes: [(String, CpToolType)] = [
        ("ADD_ANGLE_BISECTOR", CpToolType.ADD_ANGLE_BISECTOR),
        ("ADD_LINE", CpToolType.ADD_LINE),
        ("ADD_LINE_EXTENSION", CpToolType.ADD_LINE_EXTENSION),
        ("ADD_MIRRORED_LINES", CpToolType.ADD_MIRRORED_LINES),
        ("ADD_PERPENDICULAR_BISECTOR", CpToolType.ADD_PERPENDICULAR_BISECTOR),
        ("ADD_PERPENDICULAR_SEGMENT", CpToolType.ADD_PERPENDICULAR_SEGMENT),
        ("ADD_SEGMENT", CpToolType.ADD_SEGMENT),
        ("ADD_SEGMENT_BY_VALUE", CpToolType.ADD_SEGMENT_BY_VALUE),
        ("ADD_SYMMETRICAL_SEGMENT", CpToolType.ADD_SYMMETRICAL_SEGMENT),
        ("ADD_TRIANGLE_INCENTER", CpToolType.ADD_TRIANGLE_INCENTER),
        ("CHANGE_LINE", CpToolType.CHANGE_LINE),
        ("DELETE_LINE", CpToolType.DELETE_LINE),
        ("DELETE_VERTEX", CpToolType.DELETE_VERTEX),
        ("SELECT_LINE", CpToolType.SELECT_LINE),
    ]

    private static let transitionResults: [(String, CpTransitionResult)] = [
        ("CHANGED_LINES", CpTransitionResult.CHANGED_LINES),
        ("CHANGED_POINTS", CpTransitionResult.CHANGED_POINTS),
        ("FINISHED", CpTransitionResult.FINISHED),
        ("NO_CHANGE", CpTransitionResult.NO_CHANGE),
    ]

    private static let events: [(String, CpEvent)] = [
        ("CONFIRM_LINE", CpEvent.CONFIRM_LINE),
        ("CONFIRM_POINT", CpEvent.CONFIRM_POINT),
        ("FINISH", CpEvent.FINISH),
        ("SET_TEMP_LINE", CpEvent.SET_TEMP_LINE),
        ("SET_TEMP_POINT", CpEvent.SET_TEMP_POINT),
    ]

    private static let changeLineRIDs: [(String, Int)] = [
        ("FROM_ANY", ChangeLineSM.RID.FROM_ANY),
        ("FROM_BOUNDARY", ChangeLineSM.RID.FROM_BOUNDARY),
        ("FROM_FLAT", ChangeLineSM.RID.FROM_FLAT),
        ("FROM_MOUNTAIN", ChangeLineSM.RID.FROM_MOUNTAIN),
        ("FROM_VALLEY", ChangeLineSM.RID.FROM_VALLEY),
        ("TO_BOUNDARY", ChangeLineSM.RID.TO_BOUNDARY),
        ("TO_FLAT", ChangeLineSM.RID.TO_FLAT),
        ("TO_FLIP", ChangeLineSM.RID.TO_FLIP),
        ("TO_MOUNTAIN", ChangeLineSM.RID.TO_MOUNTAIN),
        ("TO_VALLEY", ChangeLineSM.RID.TO_VALLEY),
    ]

    private static let deleteLineRIDs: [(String, Int)] = [
        ("ANY", DeleteLineSM.RID.ANY),
        ("BOUNDARY", DeleteLineSM.RID.BOUNDARY),
        ("FLAT", DeleteLineSM.RID.FLAT),
        ("MOUNTAIN", DeleteLineSM.RID.MOUNTAIN),
        ("VALLEY", DeleteLineSM.RID.VALLEY),
    ]

    private static func run(_ harness: TestHarness) throws {
        let fixture = try Fixtures.decode(ToolsFixture.self, "Fixtures/tools/tools.json")
        let constants = fixture.constants

        harness.expectEqual(constants.toolType.count, toolTypes.count, "tool type count")
        for (name, value) in toolTypes {
            harness.expectEqual(
                constants.toolType[name] ?? Int.min, value.rawValue, "CpToolType.\(name)"
            )
        }

        harness.expectEqual(
            constants.transitionResult.count, transitionResults.count, "transition result count"
        )
        for (name, value) in transitionResults {
            harness.expectEqual(
                constants.transitionResult[name] ?? Int.min,
                value.rawValue,
                "CpTransitionResult.\(name)"
            )
        }

        harness.expectEqual(constants.event.count, events.count, "event count")
        for (name, value) in events {
            harness.expectEqual(
                constants.event[name] ?? Int.min, value.rawValue, "CpEvent.\(name)"
            )
        }

        harness.expectEqual(
            constants.changeLineRID.count, changeLineRIDs.count, "ChangeLineSM RID count"
        )
        for (name, value) in changeLineRIDs {
            harness.expectEqual(
                constants.changeLineRID[name] ?? Int.min, value, "ChangeLineSM.RID.\(name)"
            )
        }

        harness.expectEqual(
            constants.deleteLineRID.count, deleteLineRIDs.count, "DeleteLineSM RID count"
        )
        for (name, value) in deleteLineRIDs {
            harness.expectEqual(
                constants.deleteLineRID[name] ?? Int.min, value, "DeleteLineSM.RID.\(name)"
            )
        }

        harness.expectEqual(
            constants.changeLinePrefKeys.FROM,
            ChangeLineSM.PREF_KEY_PAINT_CHANGE_LINE_TYPE_FROM,
            "ChangeLineSM from pref key"
        )
        harness.expectEqual(
            constants.changeLinePrefKeys.TO,
            ChangeLineSM.PREF_KEY_PAINT_CHANGE_LINE_TYPE_TO,
            "ChangeLineSM to pref key"
        )
        harness.expectEqual(
            constants.deleteLinePrefKey,
            DeleteLineSM.PREF_KEY_PAINT_DELETE_LINE_TYPE,
            "DeleteLineSM pref key"
        )
    }
}
