// Test runner entry point.
//
//   swift run ORIPATests            # run everything (local + CI)
//   swift run ORIPATests CoreModel  # only suites whose name contains "CoreModel"
//
// Suites are registered by the `core-model` and `fold-io` workstreams via the static
// `all` arrays in CoreModel/CoreModelTests.swift and FoldIO/FoldIOTests.swift. Both lists
// may be empty while a workstream is in progress.
import Foundation

let harness = TestHarness()
let filter = CommandLine.arguments.dropFirst().first

func filtered(_ suites: [TestSuite]) -> [TestSuite] {
    guard let filter, !filter.isEmpty else { return suites }
    return suites.filter { $0.name.localizedCaseInsensitiveContains(filter) }
}

for suite in filtered(CoreModelTests.all) { harness.run(suite) }
for suite in filtered(FoldIOTests.all) { harness.run(suite) }

print(harness.summary())
exit(harness.failures.isEmpty ? 0 : 1)
