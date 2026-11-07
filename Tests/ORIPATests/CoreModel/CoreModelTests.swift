// Core-model test suite registry. OWNER: core-model.
//
// Add one TestSuite per ported area (mirroring oripa-port/tools/tests/test_core_*.js):
// trees, creasepattern, history, geom, statemachine, tools. Use the shared harness and
// the Fixtures loader; keep the original JS suite/section names in the suite names.
import Foundation

enum CoreModelTests {
    static var all: [TestSuite] {
        []
    }
}
