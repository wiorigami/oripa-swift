// Fold-io test suite registry. OWNER: fold-io.
//
// The shared runner (`Tests/ORIPATests/main.swift`, Lead-owned) runs the registries
// separately: CoreModelTests, CoreTreeTests, CoreToolsTests, FoldIOTests (this file) and
// FoldModelTestSuites (fold-engine). Do not add other workstreams' suites here.
//
// Suites mirror the reference JS test files:
//   FoldIOIOTests         <- oripa-port/tools/tests/test_fold_io_roundtrip.js
//   FoldIORenderDataTests <- oripa-port/tools/tests/test_render_renderdata.js (GLData*)
//   FoldIOOracleTests     <- oripa-port/tools/tests/test_fold_oracle_cases.js
import Foundation
import ORIPACore

enum FoldIOTests {
    static var all: [TestSuite] {
        FoldIOIOTests.all + FoldIORenderDataTests.all + FoldIOOracleTests.all
    }
}
