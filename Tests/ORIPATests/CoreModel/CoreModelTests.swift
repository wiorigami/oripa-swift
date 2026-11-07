// Core-model test suite registry. OWNER: core-model.
//
// Suites mirror the reference JS suites (oripa-port/tools/tests/test_core_*.js):
// resources/geometry (test_core_geom), collections/Java collections (test_core_geom +
// test_core_history infra), model entities + grid (test_core_creasepattern),
// CreasePattern + HistoryManager (test_core_creasepattern + test_core_history).
// Tree/spatial-index goldens live in CoreTreeTests (lead), tools/* in CoreToolsTests.
import Foundation

enum CoreModelTests {
    static var all: [TestSuite] {
        var suites: [TestSuite] = []
        suites.append(contentsOf: ResourcesTests.all)
        suites.append(contentsOf: GeomTests.all)
        suites.append(contentsOf: CollectionsTests.all)
        suites.append(contentsOf: ModelTests.all)
        suites.append(contentsOf: CreasePatternTests.all)
        return suites
    }
}
