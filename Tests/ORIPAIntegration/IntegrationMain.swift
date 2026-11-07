// End-to-end integration checks for the native ORIPA app layer.
//
//   swift run ORIPAIntegration
//
// Unlike ORIPATests (golden logic checks, ORIPACore only), this executable drives the real
// ORIPAUI app objects on the macOS target: ProjectStore disk persistence, EditorSession with
// the paint state machines, save/reload across a fresh store instance ("relaunch"), crash-safe
// autosave recovery, external file import, the fold pipeline on a certified oracle case, and
// CP/OPX/SVG exports. It is the functional verification for the user's "projects must not be
// lost" requirement and for the editor integration (headless, no window server).
import Foundation
import CoreGraphics
import ORIPACore
import ORIPAUI

@main
struct ORIPAIntegrationMain {
    static func main() async {
        let ok = await MainActor.run { IntegrationChecks().runAll() }
        exit(ok ? 0 : 1)
    }
}

@MainActor
final class IntegrationChecks {
    private var checks = 0
    private var failures: [String] = []

    private let fileManager = FileManager.default
    private var rootURL: URL!
    private var store: ProjectStore!
    private var prefs: Preferences!
    private var app: AppModel!

    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // ORIPAIntegration
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repository root

    // MARK: - Harness

    private func expect(_ condition: Bool, _ message: @autoclosure () -> String) {
        checks += 1
        if !condition {
            let text = message()
            failures.append(text)
            print("FAIL \(text)")
        }
    }

    private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
        expect(actual == expected, "\(label): expected \(expected), got \(actual)")
    }

    private func expectClose(_ actual: Double, _ expected: Double, _ label: String, accuracy: Double = 1e-9) {
        expect(abs(actual - expected) <= accuracy, "\(label): expected \(expected) ± \(accuracy), got \(actual)")
    }

    func runAll() -> Bool {
        print("ORIPA integration checks")
        rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("oripa-integration-\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        store = ProjectStore(rootURL: rootURL)
        let defaults = UserDefaults(suiteName: "oripa.integration.\(UUID().uuidString)") ?? .standard
        prefs = Preferences(defaults: defaults)
        app = AppModel(navigation: [.projects], prefs: prefs, store: store)

        checkProjectStoreBasics()
        checkDrawUndoSaveReload()
        checkProjectCrud()
        checkTempAutosaveRecovery()
        checkImportAndFold()
        checkExports()
        checkPreferences()

        if failures.isEmpty {
            print("PASS \(checks) integration checks")
        } else {
            print("FAIL \(checks) checks, \(failures.count) failures")
        }

        try? fileManager.removeItem(at: rootURL)
        return failures.isEmpty
    }

    // MARK: - 1. ProjectStore disk layout

    private func checkProjectStoreBasics() {
        expectEqual(store.projects.count, 0, "new store has no projects")
        expect(fileManager.fileExists(atPath: store.projectDataURL.path), "project_data directory exists")
        expect(fileManager.fileExists(atPath: store.projectThumbURL.path), "project_thumbs directory exists")
        expect(fileManager.fileExists(atPath: store.importDataURL.path), "import_data directory exists")
        expectEqual(store.uniqueName(base: "untitled"), "untitled", "first free internal name")
    }

    // MARK: - 2. Paint → save → reload across a fresh store

    private func checkDrawUndoSaveReload() {
        let session = EditorSession(params: EditorParams(), app: app)
        expectEqual(session.cp.lines.count, 4, "new project starts from the default square")
        expectEqual(session.srcFilenameNoExtValue, "untitled", "new project file name")

        let menu = PaintMenuModel(prefs: prefs)
        let viewTransform = ViewTransform(viewportW: 820, viewportH: 1180)
        viewTransform.setObjectHalfSize(CGFloat(session.cp.creasePatternHalfSize))
        let renderer = PaintRenderer(viewTransform: viewTransform)
        let driver = PaintDriver(session: session, menu: menu, renderer: renderer)
        driver.initialize()

        let before = session.cp.lines.count
        tap(driver, viewTransform, -100, -100)
        tap(driver, viewTransform, 100, 100)
        let afterDraw = session.cp.lines.count
        expect(afterDraw == before + 1, "two taps draw one line (before \(before), after \(afterDraw))")
        expect(session.cp.modified, "drawing marks the pattern modified")
        expect(session.cp.historyManager.hasUndo(), "drawing creates an undo branch")

        driver.undo()
        expectEqual(session.cp.lines.count, before, "undo removes the drawn line")
        driver.redo()
        expectEqual(session.cp.lines.count, afterDraw, "redo restores the drawn line")

        let projectName = session.srcFilenameNoExtValue
        session.saveChangesToCurrent()

        expect(store.projectExists(name: projectName), "project file written under Documents/project_data")
        expect(store.projects.count == 1, "projects list refreshed from disk")
        expect(store.hasThumb(name: projectName), "180 px project thumbnail persisted under project_thumbs")

        // Fresh store instance = app relaunch reading the same container.
        let relaunched = ProjectStore(rootURL: rootURL)
        expect(relaunched.projectExists(name: projectName), "project visible after relaunch (new ProjectStore)")
        guard let bytes = relaunched.readProject(name: projectName) else {
            expect(false, "saved OPXC bytes readable after relaunch")
            return
        }
        expect(bytes.count > 0, "saved OPXC file is non-empty")
        if let reloaded = try? OripaIO.loadCreasePatternForce(data: bytes) {
            expectEqual(reloaded.lines.count, afterDraw, "reloaded project keeps the drawn lines")
        } else {
            expect(false, "saved OPXC reloads through OripaIO.loadCreasePatternForce")
        }
    }

    private func tap(_ driver: PaintDriver, _ viewTransform: ViewTransform, _ x: Double, _ y: Double) {
        let screen = viewTransform.objectToScreen(x: CGFloat(x), y: CGFloat(y))
        driver.tap(x: screen.x, y: screen.y)
    }

    // MARK: - 3. Rename / copy / delete persistence

    private func checkProjectCrud() {
        let original = "untitled"
        expect(store.projectExists(name: original), "project from previous check still on disk")

        guard let copied = try? store.copy(name: original) else {
            expect(false, "copy project")
            return
        }
        expect(copied != original, "copy gets a distinct file name (\(copied))")
        expect(store.projectExists(name: copied), "copied project exists on disk")

        guard let renamed = try? store.rename(oldName: copied, to: "integration-renamed") else {
            expect(false, "rename project")
            return
        }
        expectEqual(renamed, "integration-renamed", "renamed project name")
        expect(store.projectExists(name: renamed), "renamed project exists on disk")

        do {
            try store.delete(name: renamed)
        } catch {
            expect(false, "delete project threw \(error)")
        }
        expect(!store.projectExists(name: renamed), "deleted project removed from disk")
        expect(store.projectExists(name: original), "unrelated project untouched by delete")
    }

    // MARK: - 4. Crash-safe autosave / recovery

    private func checkTempAutosaveRecovery() {
        guard let session = Optional(EditorSession(params: EditorParams(projectName: "untitled"), app: app)) else {
            expect(false, "reopen saved project")
            return
        }
        let reopenedLines = session.cp.lines.count
        expect(reopenedLines >= 5, "reopened project loads its crease pattern (\(reopenedLines) lines)")

        let added = session.cp.addLineCheckNoException(
            OriPoint(-150, 50), OriPoint(150, 50), LineType.valley
        )
        expect(added, "adding a valley line to the reopened project succeeds")
        session.markModified()

        session.autosaveTemp()
        expect(fileManager.fileExists(atPath: store.tempSaveURL.path), "autosave wrote temp_save_file to disk")
        expect(fileManager.fileExists(atPath: store.tempSaveMetaURL.path), "autosave wrote temp_save_meta.json")

        // Simulated crash/relaunch: the draft must be recoverable and loadable.
        let relaunched = ProjectStore(rootURL: rootURL)
        guard let draft = relaunched.recoverableDraft() else {
            expect(false, "unsaved draft is recoverable after relaunch")
            return
        }
        expectEqual(draft.projectName, "untitled", "draft remembers the source project name")
        guard let (draftBytes, _) = relaunched.readTempSave() else {
            expect(false, "draft bytes readable")
            return
        }
        if let draftCP = try? OripaIO.loadCreasePatternForce(data: draftBytes) {
            expectEqual(draftCP.lines.count, reopenedLines + 1, "recovered draft keeps the unsaved line")
        } else {
            expect(false, "recovered draft loads through OripaIO")
        }
        relaunched.deleteTempSave()
        expect(!fileManager.fileExists(atPath: relaunched.tempSaveURL.path), "discarding recovery removes the temp file")
        expect(relaunched.recoverableDraft() == nil, "no draft left after deletion")
    }

    // MARK: - 5. External import + fold pipeline

    private func checkImportAndFold() {
        let casesURL = repoRoot.appendingPathComponent("Fixtures/cases", isDirectory: true)
        guard let craneBytes = try? Data(contentsOf: casesURL.appendingPathComponent("crane_base_mitani.opx")) else {
            expect(false, "fixture Fixtures/cases/crane_base_mitani.opx is readable")
            return
        }
        guard let staged = try? store.createImportStaging(data: craneBytes, filename: "crane_base_mitani.opx") else {
            expect(false, "import staging copy into Documents/import_data")
            return
        }
        expect(fileManager.fileExists(atPath: staged.url.path), "staged import file exists on disk")

        let session = EditorSession(
            params: EditorParams(srcFilenameWithExt: staged.name,
                                 srcProjectDirPath: AppInfo.importDataDirectory,
                                 srcIsInternal: false),
            app: app
        )
        expect(session.cp.lines.count > 0, "external OPX import loads its crease pattern")
        expect(session.modified, "external import is marked modified")
        expectEqual(session.entryError, nil, "external import loads without an error")

        let foldable = session.prepareFold()
        expect(foldable, "certified crane base is flat-foldable and folds")
        expectEqual(session.foldedModel.mFaces.count, 12, "crane base folds to 12 faces")
        expect(session.foldedModel.mVertices.count > 0, "folded model has vertices")
        expect(session.foldedModel.mHalfEdges.count > 0, "folded model has half edges")
        expectEqual(session.foldedModel.componentCount, 1, "folded model is a single connected component")

        expect(session.exportSVGData() != nil, "crease-pattern SVG export works")
        expect(session.exportPNGData(sizePx: 1024) != nil, "crease-pattern PNG export works")
        session.discardChanges()
    }

    // MARK: - 6. Export round-trips on the saved project

    private func checkExports() {
        guard let bytes = store.readProject(name: "untitled"),
              let cp = try? OripaIO.loadCreasePatternForce(data: bytes) else {
            expect(false, "saved project loads for export checks")
            return
        }
        let lineCount = cp.lines.count

        let cpData = OripaIO.exportCp(cp)
        expect(cpData.count > 0, "CP export produces bytes")
        if let reloaded = try? OripaIO.loadCreasePattern(data: cpData, fileType: .cp) {
            expectEqual(reloaded.lines.count, lineCount, "CP export reloads with the same line count")
        } else {
            expect(false, "CP export reloads through OripaIO.loadCreasePattern")
        }

        let opx = OripaIO.exportOpx(cp)
        expect(opx.count > 0, "OPX export produces bytes")
        if let reloaded = try? OripaIO.loadCreasePattern(data: opx, fileType: .opx) {
            expectEqual(reloaded.lines.count, lineCount, "OPX export reloads with the same line count")
        } else {
            expect(false, "OPX export reloads through OripaIO.loadCreasePattern")
        }

        let opxc = OripaIO.exportOpxc(cp)
        expect(opxc.count > 0, "OPXC export produces bytes")
        if let reloaded = try? OripaIO.loadCreasePatternForce(data: opxc) {
            expectEqual(reloaded.lines.count, lineCount, "OPXC export reloads with the same line count")
        } else {
            expect(false, "OPXC export reloads through OripaIO.loadCreasePatternForce")
        }

        let svg = OripaIO.exportSvg(cp)
        expect(svg.contains("<svg"), "SVG export produces an SVG document")
        expectEqual(ProjectStore.filenameWithExt("crane", fileType: .opx), "crane.opx",
                    "export file name helper")

        // Reference corpus: load every certified case through the public API.
        let casesURL = repoRoot.appendingPathComponent("Fixtures/cases", isDirectory: true)
        let caseNames = (try? fileManager.contentsOfDirectory(atPath: casesURL.path))?.sorted() ?? []
        expect(!caseNames.isEmpty, "certified oracle case corpus present")
        for name in caseNames {
            guard let data = try? Data(contentsOf: casesURL.appendingPathComponent(name)) else { continue }
            guard let loaded = try? OripaIO.readCreasePatternFile(data: data, filename: name) else {
                expect(false, "oracle case \(name) loads through readCreasePatternFile")
                continue
            }
            expect(loaded.lines.count > 0, "oracle case \(name) has lines")
        }
    }

    // MARK: - 7. Android-preferences parity

    private func checkPreferences() {
        expectEqual(prefs.bool(Preferences.Key.showGrid, default: true), true,
                    "default show grid preference")
        prefs.setBool(false, for: Preferences.Key.showGrid)
        expectEqual(prefs.bool(Preferences.Key.showGrid, default: true), false,
                    "preference value persists in the store")
        prefs.setInt(8, for: Preferences.Key.gridDivisions)
        expectEqual(prefs.int(Preferences.Key.gridDivisions, default: 4), 8,
                    "grid divisions preference")
        prefs.clear()
        expectEqual(prefs.bool(Preferences.Key.showGrid, default: true), true,
                    "Android clear() restores defaults")
    }
}
