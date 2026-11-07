// Core tool state-machine test suite registry. OWNER: core-tools.
//
// Mirror oripa-port/tools/tests/test_core_statemachine.js: per-tool event sequences
// (AddSegment/AddLine/AddPerpendicularSegment/DeleteLine/DeleteVertex/ChangeLine/
// SelectLine/AddMirroredLines/AddTriangleIncenter/AddSegmentByValue trio/...).
import Foundation

enum CoreToolsTests {
    static var all: [TestSuite] {
        []
    }
}
