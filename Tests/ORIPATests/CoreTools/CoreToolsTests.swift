// Core tool state-machine test suite registry. OWNER: core-tools.
//
// Suites (mirroring oripa-port/tools/tests/test_core_statemachine.js):
//   CoreToolsConstantsTests  — CpToolType/CpEvent/CpTransitionResult/RID/pref-key constants.
//   CoreToolsScenarioTests   — every tool machine + StateMachineManager replayed against the
//                              golden JSON in Fixtures/tools/tools.json (generated from the JS).
//   CoreToolsBehaviorTests   — object lifecycle / flags / nil-context safety checks.
import Foundation

enum CoreToolsTests {
    static var all: [TestSuite] {
        ToolsConstantsTests.all + ToolsScenarioTests.all + ToolsBehaviorTests.all
    }
}
