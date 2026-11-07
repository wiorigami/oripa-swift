// Fold-io test suite registry. OWNER: fold-io.
//
// Add one TestSuite per ported area (mirroring oripa-port/tools/tests/test_fold_io_*.js
// and test_fold_oracle_cases.js): file IO + round-trips, folded-model geometry/invariants,
// oracle cases, SVG output, render-data encodings, malformed inputs.
import Foundation

enum FoldIOTests {
    static var all: [TestSuite] {
        []
    }
}
