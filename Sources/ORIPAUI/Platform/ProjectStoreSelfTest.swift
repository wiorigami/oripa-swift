// Persistence self-test for `ProjectStore`.
//
// The user requirement is that crease-pattern projects are real files on disk that survive
// app termination/relaunch. This test writes projects through one store instance, re-reads
// them through brand-new instances (simulating a relaunch/process restart), and exercises
// rename/copy/delete, import staging and the crash-safe temp autosave + recovery metadata.
//
// It can be run from any executable target that links ORIPAUI:
//
//     let result = ProjectStore.runSelfTest()
//     print(result.report)          // PASS/FAIL lines
//     exit(result.passed ? 0 : 1)
import Foundation
import ORIPACore

/// Result of `ProjectStore.runSelfTest()`.
public struct ProjectStoreSelfTestResult {
    public let passed: Bool
    public let report: String

    public init(passed: Bool, report: String) {
        self.passed = passed
        self.report = report
    }
}

@MainActor
public extension ProjectStore {

    /// Write → relaunch(re-read) → rename → copy → delete → staging → temp autosave test.
    static func runSelfTest() -> ProjectStoreSelfTestResult {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("oripa-persist-selftest-\(UUID().uuidString)", isDirectory: true)
        var checks: [(String, Bool)] = []

        func check(_ label: String, _ condition: Bool) {
            checks.append((label, condition))
        }

        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

            // 1. Write through a fresh store.
            let store1 = ProjectStore(rootURL: root)
            let opxcA = Data("ORIPA-OPXC-A".utf8)
            let opxcB = Data("ORIPA-OPXC-B".utf8)
            let thumbA = Data("PNG-A".utf8)
            try store1.write(name: "crane base", opxc: opxcA, thumbPNG: thumbA)
            try store1.write(name: "untitled", opxc: opxcB, thumbPNG: Data("PNG-B".utf8))
            check("write creates project_data/<name>", store1.projectExists(name: "crane base"))
            check("write creates project_thumbs/<name>", store1.hasThumb(name: "crane base"))
            check("write publishes project list", store1.projects.map(\.name).sorted() == ["crane base", "untitled"])

            // 2. Simulate an app relaunch: a brand-new ProjectStore instance over the same root.
            let store2 = ProjectStore(rootURL: root)
            check("relaunch lists both projects", Set(store2.projects.map(\.name)) == ["crane base", "untitled"])
            check("relaunch reads project bytes", store2.readProject(name: "crane base") == opxcA)
            check("relaunch reads thumbnail bytes", store2.readThumb(name: "crane base") == thumbA)
            check("modified date survives relaunch", (store2.projectInfo(name: "crane base")?.modifiedAt ?? .distantPast) > Date(timeIntervalSince1970: 0))

            // 3. Unique naming rules (Exporter.getNewUniqueFile / getNewCopyFile).
            check("unique name appends -1", store2.uniqueName(base: "crane base") == "crane base-1")
            store1.writeTempSave(Data(), meta: TempSaveMeta())
            try store2.write(name: "crane base-1", opxc: Data("X".utf8), thumbPNG: nil)
            check("unique name skips existing -1", store2.uniqueName(base: "crane base") == "crane base-2")
            check("copy name appends -copy", store2.copyName(base: "crane base") == "crane base-copy")

            // 4. Rename (project + thumbnail), visible to another instance.
            let renamed = try store2.rename(oldName: "untitled", to: "hydrangea")
            check("rename returns target name", renamed == "hydrangea")
            let store3 = ProjectStore(rootURL: root)
            check("rename removes old project", !store3.projectExists(name: "untitled"))
            check("rename renames thumbnail", store3.hasThumb(name: "hydrangea"))
            check("rename keeps bytes", store3.readProject(name: "hydrangea") == opxcB)

            // 5. Copy then delete.
            let copyName = try store3.copy(name: "crane base")
            check("copy uses name-copy", copyName == "crane base-copy")
            let store4 = ProjectStore(rootURL: root)
            check("copy visible after reload", store4.readProject(name: copyName) == opxcA)
            check("copy duplicates thumbnail", store4.readThumb(name: copyName) == thumbA)
            try store4.delete(name: copyName)
            let store5 = ProjectStore(rootURL: root)
            check("delete removes project file", !store5.projectExists(name: copyName))
            check("delete removes thumbnail", !store5.hasThumb(name: copyName))
            check("delete keeps project list consistent", !store5.projects.contains { $0.name == copyName })

            // 6. Import staging in Documents/import_data.
            let staged = try store5.createImportStaging(data: Data("OPX".utf8), filename: "crane.opx")
            check("staging keeps original filename", staged.name == "crane.opx")
            check("staging directory is import_data", staged.url.deletingLastPathComponent().lastPathComponent == AppInfo.importDataDirectory)
            let stagedDuplicate = try store5.createImportStaging(data: Data("OPX2".utf8), filename: "crane.opx")
            check("staging de-duplicates names", stagedDuplicate.name == "crane-1.opx")
            let store6 = ProjectStore(rootURL: root)
            check("staged file readable from new instance", store6.readStaging(name: "crane.opx") == Data("OPX".utf8))
            store6.cleanupStaging()
            check("cleanupStaging empties import_data", store6.stagingFiles().isEmpty)

            // 7. Crash-safe temp autosave + recovery metadata.
            let meta = TempSaveMeta(savedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                    projectName: "crane base",
                                    srcFilenameNoExt: "crane base",
                                    srcIsInternal: true,
                                    fragment: "paint",
                                    modified: true)
            store6.writeTempSave(opxcA, meta: meta)
            let store7 = ProjectStore(rootURL: root)
            let recovered = store7.readTempSave()
            check("autosave data readable after relaunch", recovered?.0 == opxcA)
            check("autosave metadata readable after relaunch", recovered?.1 == meta)
            check("recoverableDraft reports pending work", store7.recoverableDraft() != nil)
            store7.deleteTempSave()
            let store8 = ProjectStore(rootURL: root)
            check("deleteTempSave clears draft", store8.recoverableDraft() == nil)

            // 8. Atomic writes leave no temporary droppings behind.
            let contents = (try? fileManager.contentsOfDirectory(atPath: store8.projectDataURL.path)) ?? []
            check("no temporary files left in project_data", !contents.contains { $0.hasPrefix(".") })
            check("project files have no extension", contents.allSatisfy { !$0.contains(".") })
        } catch {
            check("unexpected error: \(error.localizedDescription)", false)
        }

        try? fileManager.removeItem(at: root)

        let passed = checks.allSatisfy(\.1)
        var lines: [String] = []
        lines.append("ProjectStore persistence self-test: \(passed ? "PASS" : "FAIL")")
        for (label, ok) in checks {
            lines.append("  [\(ok ? "PASS" : "FAIL")] \(label)")
        }
        lines.append("  \(checks.filter(\.1).count)/\(checks.count) checks passed")
        return ProjectStoreSelfTestResult(passed: passed, report: lines.joined(separator: "\n"))
    }
}
