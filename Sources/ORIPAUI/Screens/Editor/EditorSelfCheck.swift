// Headless verification of the editor session + rendering flows.
//
// Used by the snapshot harness / CI QA to prove the real code paths without a window
// server: New File entry, the AddSegment tap → state machine → history → renderer chain,
// undo/redo, PNG/thumbnail export (sizes checked), SVG/OPX/CP export, save + cleanAndExit,
// save-to-copy, internal project load, staged external import, back-handler re-entrancy and
// the fold hand-off. Returns PASS/FAIL lines (see `EditorSelfCheck.run(app:)`).
import Foundation
import ImageIO
import ORIPACore
import SwiftUI

@MainActor
public enum EditorSelfCheck {
    public static func run(app: AppModel) -> [String] {
        var out: [String] = []
        func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
            let extra = detail()
            out.append("\(condition ? "PASS" : "FAIL") \(name)\(extra.isEmpty ? "" : " — \(extra)")")
        }

        // MARK: 1. New File entry: default square + unique untitled name.

        let session = EditorSession(params: EditorParams(), app: app)
        check("new-file default square", session.cp.lines.count == 4, "lines=\(session.cp.lines.count)")
        check("new-file name", session.srcFilenameNoExt.hasPrefix("untitled"),
              session.srcFilenameNoExt)
        check("new-file unmodified", session.cp.modified == false)
        check("new-file internal", session.srcIsInternal)

        // MARK: 2. Paint renderer setup (grid + typed lines + vertices render data).

        let menu = PaintMenuModel(prefs: app.prefs)
        let renderer = PaintRenderer()
        let driver = PaintDriver(session: session, menu: menu, renderer: renderer)
        let coordinator = PaintCoordinator(session: session, menu: menu, driver: driver,
                                           renderer: renderer, app: app)
        coordinator.configureRenderer()
        renderer.prepareForSize(SnapshotScenarios.portrait)
        check("paint grid render data", renderer.gridLines.count == 10,
              "grid=\(renderer.gridLines.count)")
        check("paint line render data", !renderer.lineSets.isEmpty,
              "sets=\(renderer.lineSets.count)")
        check("paint point render data", renderer.cpPoints.count == 4,
              "points=\(renderer.cpPoints.count)")
        check("paint initial line type", session.cp.inputLineType == .mountain,
              "\(session.cp.inputLineType)")

        // MARK: 3. AddSegment tap flow → history branch, undo enabled, modified flag.

        let before = session.cp.lines.count
        let center = CGPoint(x: 410, y: 590)
        let scale = CGFloat(1180) / (2.0 * CGFloat(session.cp.creasePatternHalfSize))
        func tap(_ ox: CGFloat, _ oy: CGFloat) {
            driver.tap(x: center.x + ox * scale * 0.5, y: center.y + oy * scale * 0.5)
        }
        tap(-100, -200)
        tap(200, 100)
        check("AddSegment draws", session.cp.lines.count > before,
              "\(before)->\(session.cp.lines.count)")
        check("AddSegment undo enabled", driver.canUndo)
        check("AddSegment modified", session.cp.modified)

        let afterDraw = session.cp.lines.count
        driver.undo()
        check("undo restores lines", session.cp.lines.count == before,
              "\(afterDraw)->\(session.cp.lines.count)")
        driver.redo()
        check("redo re-adds lines", session.cp.lines.count == afterDraw)

        // MARK: 4. Picked render data (port of updatePickedPoints / updatePickedLines).

        renderer.setPickedLines([PaintLine(x0: -100, y0: 0, x1: 0, y1: 0, typeCode: 2)])
        renderer.setPickedMVFBPoints([PaintPoint(x: -100, y: 0)])
        check("picked line render data", renderer.pickedLines.count == 1)
        check("picked point render data", renderer.pickedMVFBPoints.count == 1)

        // MARK: 5. PNG export (1000 px square + 180 px thumbnail).

        let pngOptions = CPPNGExportOptions(background: CanvasRGB(1, 1, 1),
                                            showGrid: true, showFlatLines: true,
                                            dashed: false, thumbnail: false,
                                            lineWidthScale: 2.0)
        let png = CoreRenderBridge.renderPNG(cp: session.cp, width: 1000, height: 1000,
                                             options: pngOptions)
        check("CP PNG export", png != nil, "bytes=\(png?.count ?? 0)")
        check("CP PNG 1000x1000", png.flatMap(pngSize) == CGSize(width: 1000, height: 1000),
              png.flatMap(pngSize).map { "\(Int($0.width))x\(Int($0.height))" } ?? "nil")
        let thumb = CoreRenderBridge.renderThumbnail(cp: session.cp)
        check("CP thumbnail", thumb != nil, "bytes=\(thumb?.count ?? 0)")
        check("CP thumbnail 180x180", thumb.flatMap(pngSize) == CGSize(width: 180, height: 180),
              thumb.flatMap(pngSize).map { "\(Int($0.width))x\(Int($0.height))" } ?? "nil")

        // MARK: 6. CP export formats (Export CP dialog data sources).

        check("export SVG", session.exportSVGData()?.isEmpty == false)
        check("export OPX", session.exportOPXData()?.isEmpty == false)
        check("export CP", session.exportCPData()?.isEmpty == false)

        // MARK: 7. Save + thumbnail + cleanAndExit (temp deleted, prefs cleared, closed).

        app.prefs.setString("paint_pref_show_grid", for: "paint_pref_show_grid")
        session.autosaveTemp()
        check("temp autosave written", app.store.readTempSave() != nil)
        let saveName = session.srcFilenameNoExt
        session.saveChangesToCurrent()
        check("save writes project_data opxc", app.store.projectExists(name: saveName), saveName)
        check("save writes project_thumbs png", app.store.hasThumb(name: saveName))
        check("cleanAndExit deletes temp", app.store.readTempSave() == nil)
        check("cleanAndExit clears prefs", app.prefs.value("paint_pref_show_grid") == nil)
        check("cleanAndExit clears cp", session.cp.lines.isEmpty, "lines=\(session.cp.lines.count)")
        check("cleanAndExit closes session", session.closed)

        // MARK: 8. Save-to-copy naming (`-copy`).

        let copySession = EditorSession(params: EditorParams(), app: app)
        copySession.cp.modified = true
        let original = copySession.srcFilenameNoExt
        copySession.saveChangesToCopy()
        let copies = app.store.projects.map(\.name).filter { $0.hasPrefix(original + "-copy") }
        check("save-to-copy writes -copy project", !copies.isEmpty, copies.joined(separator: ","))

        // MARK: 9. Open an existing internal project (OPXC, unmodified, name kept).

        let seedCP = CreasePattern()
        seedCP.initializeDefaultSquare()
        seedCP.addLineCheckNoException(OriLine(OriPoint(-100, 0), OriPoint(100, 0), LineType.valley))
        let seedName = app.store.uniqueName(base: "selfcheck-project")
        try? app.store.write(name: seedName, opxc: OripaIO.exportOpxc(seedCP), thumbPNG: nil)
        let opened = EditorSession(params: EditorParams(projectName: seedName), app: app)
        check("open internal project lines", opened.cp.lines.count == seedCP.lines.count,
              "\(seedCP.lines.count)->\(opened.cp.lines.count)")
        check("open internal unmodified", opened.cp.modified == false)
        check("open internal name", opened.srcFilenameNoExt == seedName, opened.srcFilenameNoExt)

        // MARK: 10. Staged external import (import_data/<file>) — modified + unique name.

        try? FileManager.default.createDirectory(at: app.store.importDataURL,
                                                 withIntermediateDirectories: true)
        let stagedName = "selfcheck-import.opx"
        try? OripaIO.exportOpx(seedCP).write(to: app.store.importDataURL
            .appendingPathComponent(stagedName))
        let imported = EditorSession(params: EditorParams(srcFilenameWithExt: stagedName,
                                                          srcProjectDirPath: "import_data",
                                                          srcIsInternal: false),
                                     app: app)
        check("external import lines", imported.cp.lines.count == seedCP.lines.count,
              "\(imported.cp.lines.count)")
        check("external import modified", imported.cp.modified)
        check("external import name", imported.srcFilenameNoExt.hasPrefix("selfcheck-import"),
              imported.srcFilenameNoExt)

        // MARK: 11. closeProject on a modified project opens the save dialog; discard exits.

        let dialogSession = EditorSession(params: EditorParams(), app: app)
        dialogSession.cp.modified = true
        app.dialogs.closeAll()
        dialogSession.closeProject()
        check("closeProject opens save dialog", app.dialogs.isPresented)
        dialogSession.discardChanges()
        check("discard exits without dialog", dialogSession.closed)
        app.dialogs.closeAll()

        // MARK: 12. Settings resume re-applies the grid divisions.

        let resumeSession = EditorSession(params: EditorParams(), app: app)
        let resumeMenu = PaintMenuModel(prefs: app.prefs)
        let resumeRenderer = PaintRenderer()
        let resumeDriver = PaintDriver(session: resumeSession, menu: resumeMenu,
                                       renderer: resumeRenderer)
        let resumeCoordinator = PaintCoordinator(session: resumeSession, menu: resumeMenu,
                                                 driver: resumeDriver, renderer: resumeRenderer,
                                                 app: app)
        resumeCoordinator.configureRenderer()
        let grid4 = resumeRenderer.gridLines.count
        app.prefs.setInt(8, for: Preferences.Key.gridDivisions)
        resumeCoordinator.applySettings()
        check("settings resume grid 8 divisions", resumeRenderer.gridLines.count > grid4,
              "\(grid4)->\(resumeRenderer.gridLines.count)")
        app.prefs.remove(Preferences.Key.gridDivisions)

        // MARK: 13. Back semantics (editor.js EditorScreen.onBack, re-entrancy guard).

        let backPrefs = Preferences(defaults: UserDefaults(suiteName: "oripa.qa.back")!)
        backPrefs.clear()
        let backStore = ProjectStore(rootURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("oripa-selfcheck-back-\(UUID().uuidString)", isDirectory: true))
        let backApp = AppModel(navigation: [.projects], prefs: backPrefs, store: backStore)
        backApp.push(.editor(EditorParams()))
        let backRuntime = EditorSnapshotSupport.makeRuntime(app: backApp)
        backApp.setBackHandler(for: backApp.topEntry?.id) {
            EditorScreen.handleBack(runtime: backRuntime, app: backApp)
        }
        let backResult = backApp.back()
        check("back unmodified pops once", backResult && backApp.navigation.count == 1,
              "depth=\(backApp.navigation.count)")
        check("back unmodified cleans session", backRuntime.session.closed)

        backApp.push(.editor(EditorParams()))
        let dialogRuntime = EditorSnapshotSupport.makeRuntime(app: backApp)
        dialogRuntime.session.cp.modified = true
        dialogRuntime.session.onClosed = { backApp.pop() }
        backApp.setBackHandler(for: backApp.topEntry?.id) {
            EditorScreen.handleBack(runtime: dialogRuntime, app: backApp)
        }
        let consumed = backApp.back()
        check("back modified consumed by dialog", consumed && backApp.navigation.count == 2,
              "depth=\(backApp.navigation.count)")
        check("back modified save dialog open", backApp.dialogs.isPresented)
        backApp.dialogs.closeAll()
        dialogRuntime.session.discardChanges()
        check("discard pops editor once", backApp.navigation.count == 1,
              "depth=\(backApp.navigation.count)")

        // MARK: 14. Fold hand-off: default square folds; a broken pattern reports the error.

        let foldSession = EditorSession(params: EditorParams(), app: app)
        let folded = foldSession.prepareFold()
        check("prepareFold folds default square", folded)
        check("prepareFold builds folded model", !foldSession.foldedModel.mFaces.isEmpty,
              "faces=\(foldSession.foldedModel.mFaces.count)")

        let badSession = EditorSession(params: EditorParams(), app: app)
        badSession.cp.addLineCheckNoException(OriLine(OriPoint(0, 0), OriPoint(200, 0),
                                                      LineType.mountain))
        let badFolded = badSession.prepareFold()
        check("prepareFold rejects non-flat pattern", !badFolded)
        check("prepareFold sets fold error text",
              badSession.lastFoldError == PaintStrings.foldError)

        // MARK: 15. Check renderer data (pink faces + red error vertices).

        let checkSession = EditorSession(params: EditorParams(), app: app)
        _ = checkSession.cp.isFlatFoldable()
        let checkRenderer = CheckRenderer()
        CoreRenderBridge.configureCheck(checkRenderer, cp: checkSession.cp,
                                        settings: checkSession.settings)
        check("check face polygons", checkRenderer.polygons.count == 1,
              "faces=\(checkRenderer.polygons.count)")
        let badCheck = EditorSession(params: EditorParams(), app: app)
        badCheck.cp.addLineCheckNoException(OriLine(OriPoint(0, 0), OriPoint(200, 0),
                                                    LineType.mountain))
        _ = badCheck.cp.isFlatFoldable()
        let badCheckRenderer = CheckRenderer()
        CoreRenderBridge.configureCheck(badCheckRenderer, cp: badCheck.cp,
                                        settings: badCheck.settings)
        check("check error vertices", !badCheckRenderer.errorPoints.isEmpty,
              "errors=\(badCheckRenderer.errorPoints.count)")

        // MARK: 16. Other external formats (.cp / .opxc) through the import path.

        let cpStaged = "selfcheck-import.cp"
        try? OripaIO.exportCp(seedCP).write(to: app.store.importDataURL
            .appendingPathComponent(cpStaged))
        let cpImported = EditorSession(params: EditorParams(srcFilenameWithExt: cpStaged,
                                                            srcProjectDirPath: "import_data",
                                                            srcIsInternal: false),
                                       app: app)
        check("external import .cp", cpImported.cp.lines.count == seedCP.lines.count,
              "lines=\(cpImported.cp.lines.count)")

        let opxcStaged = "selfcheck-import.opxc"
        try? OripaIO.exportOpxc(seedCP).write(to: app.store.importDataURL
            .appendingPathComponent(opxcStaged))
        let opxcImported = EditorSession(params: EditorParams(srcFilenameWithExt: opxcStaged,
                                                              srcProjectDirPath: "import_data",
                                                              srcIsInternal: false),
                                         app: app)
        check("external import .opxc", opxcImported.cp.lines.count == seedCP.lines.count,
              "lines=\(opxcImported.cp.lines.count)")

        // MARK: 17. SaveExisting dialog (project file exists -> single-choice body).

        let existingSession = EditorSession(params: EditorParams(projectName: seedName), app: app)
        existingSession.cp.modified = true
        app.dialogs.closeAll()
        existingSession.closeProject()
        check("save-existing dialog has choices", app.dialogs.top?.content != nil)
        app.dialogs.closeAll()

        // MARK: 18. Empty crease pattern still renders a PNG (white page).

        let emptyPNG = CoreRenderBridge.renderPNG(cp: CreasePattern(), width: 200, height: 200,
                                                  options: CPPNGExportOptions())
        check("empty CP PNG export", emptyPNG.flatMap(pngSize) == CGSize(width: 200, height: 200),
              "bytes=\(emptyPNG?.count ?? 0)")

        // MARK: 19. Preview renderer data.

        let previewRenderer = PreviewRenderer()
        CoreRenderBridge.configurePreview(previewRenderer, cp: seedCP)
        check("preview render data", previewRenderer.lines.count == seedCP.lines.count,
              "\(previewRenderer.lines.count)")

        return out
    }

    private static func pngSize(_ data: Data) -> CGSize? {
        guard let image = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(image, 0, nil) else { return nil }
        return CGSize(width: cg.width, height: cg.height)
    }
}
