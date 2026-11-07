// The retained editor session: port of `editor/ProjectDataFragment.java` + the
// `EditorActivity` helpers (see `oripa-port/src/js/ui/screens/editor.js` `createSession`).
//
// Owns the shared CreasePattern / FoldedModel / CrossLineManager / StateMachineManager,
// the source file identity, the paint settings and the save/exit/autosave state machine:
//
//   entry:  internal OPXC project │ New File (default square) │ staged external import
//   switch: paint / check / fold fragments (retained, exactly one visible)
//   exit:   EditorActivity.onCloseProject -> SaveExisting / SaveNew dialogs
//   save:   project_data/<name> OPXC + project_thumbs/<name> 180px PNG, then cleanAndExit
//   cleanAndExit: delete temp_save_file, prefs.clear(), cp.clearAll(), pop to Projects
//   autosave: temp_save_file = exportOpxc(cp) when modified (onStop/background/leave)
//
// The saving/exit dialogs talk to this class through `SaveDialogHost`; the export dialog
// through `ExportCPHost`; the paint screen through `PaintDriver`.
import Foundation
import SwiftUI
import ORIPACore

public enum EditorFragment: String, CaseIterable {
    case paint
    case check
    case fold
}

@MainActor
public final class EditorSession: ObservableObject, EditorSessionProtocol {
    // MARK: - Shared model (ProjectDataFragment)

    public let cp: CreasePattern
    public let foldedModel: FoldedModel
    public let crossLineManager: CrossLineManager
    public let stateMachineManager: StateMachineManager

    public let prefs: Preferences
    private let store: ProjectStore
    private let app: AppModel

    // MARK: - Source identity

    public private(set) var srcFilenameNoExt: String
    public private(set) var srcIsInternal: Bool
    public var settings: EditorSettings

    // MARK: - UI state

    @Published public private(set) var fragment: EditorFragment = .paint
    @Published public private(set) var closed = false
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false
    /// Bumped whenever the crease pattern's content changes (history branch / undo / redo).
    @Published public private(set) var revision: Int = 0
    /// Set when the entry load failed (shown as the "Feature under construction" dialog).
    @Published public private(set) var entryError: String?

    /// The paint screen installs this so a finished action can refresh the renderer.
    public var onContentChanged: (() -> Void)?
    /// Called after cleanAndExit finished; the editor screen pops the navigation stack.
    public var onClosed: (() -> Void)?

    private var exitDialogOpen = false

    // MARK: - Init (createSession)

    public init(params: EditorParams, app: AppModel) {
        self.app = app
        self.prefs = app.prefs
        self.store = app.store

        // createSession(params): pick the entry path and build the crease pattern.
        let loaded = Self.loadCreasePattern(params: params, app: app)
        self.cp = loaded.cp
        self.foldedModel = FoldedModel()
        self.crossLineManager = CrossLineManager()
        self.stateMachineManager = StateMachineManager()
        self.srcFilenameNoExt = loaded.filename
        self.srcIsInternal = loaded.isInternal
        self.entryError = loaded.error
        self.settings = EditorPrefs.read(app.prefs)
    }

    /// Entry point semantics of `createSession(params)`.
    public struct LoadResult {
        public var cp: CreasePattern
        public var filename: String
        public var isInternal: Bool
        public var error: String?
    }

    public static func loadCreasePattern(params: EditorParams, app: AppModel) -> LoadResult {
        var creasePattern = CreasePattern()
        var filename = PaintStrings.untitled
        var isInternal = true
        var error: String?

        if let projectName = params.projectName {
            // Internal project_data file (OPXC bytes, no extension) — EditorActivity path:
            // srcIsInternal -> LoaderOpxc, no modified flag.
            if let bytes = app.store.readProject(name: projectName),
               let loaded = try? OripaIO.loadCreasePatternForce(data: bytes) {
                loaded.modified = false
                creasePattern = loaded
                filename = projectName
            } else {
                creasePattern.initializeDefaultSquare()
                creasePattern.modified = false
                filename = app.store.uniqueName(base: PaintStrings.untitled)
            }
            isInternal = true
        } else if let srcFilenameWithExt = params.srcFilenameWithExt {
            // External import path (EditorActivity: LoaderOpx/LoaderOpxc/LoaderCp by ext);
            // external files are marked modified because they are not internal projects.
            let dir = params.srcProjectDirPath ?? AppInfo.importDataDirectory
            let url = app.store.rootURL
                .appendingPathComponent(dir, isDirectory: true)
                .appendingPathComponent(srcFilenameWithExt)
            if let bytes = try? Data(contentsOf: url),
               let loaded = try? OripaIO.readCreasePatternFile(data: bytes, filename: srcFilenameWithExt) {
                loaded.modified = true
                creasePattern = loaded
                let noExt = filenameWithoutExtension(srcFilenameWithExt)
                filename = params.srcIsInternal ? noExt : app.store.uniqueName(base: noExt)
            } else {
                error = "External file not readable: \(srcFilenameWithExt)"
                creasePattern.initializeDefaultSquare()
                filename = app.store.uniqueName(base: PaintStrings.untitled)
            }
            isInternal = params.srcIsInternal
        } else {
            // New File (ProjectsActivity FAB): initializeDefaultSquare + unique name.
            creasePattern.initializeDefaultSquare()
            creasePattern.modified = false
            filename = app.store.uniqueName(base: PaintStrings.untitled)
            isInternal = true
        }
        return LoadResult(cp: creasePattern, filename: filename, isInternal: isInternal, error: error)
    }

    private static func filenameWithoutExtension(_ name: String) -> String {
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty else { return name }
        return (name as NSString).deletingPathExtension
    }

    // MARK: - EditorSessionProtocol

    public var srcFilenameNoExtValue: String { srcFilenameNoExt }

    public var modified: Bool { cp.modified }

    /// EditorActivity.returnToPaintFragment(): clear folded model + cross lines + check data.
    public func returnToPaint() {
        foldedModel.clear()
        crossLineManager.clear()
        cp.clearCheckData()
        setFragment(.paint)
    }

    /// `session.onBack()` / `closeProject()`: save/discard dialogs when modified.
    public func requestCloseProject() {
        closeProject()
    }

    /// PaintCpFragment.newCheckCP: `cp.isFlatFoldable()` then show the check fragment.
    @discardableResult
    public func runFlatFoldabilityCheck() -> Bool {
        _ = cp.isFlatFoldable()
        setFragment(.check)
        return true
    }

    /// PaintCpFragment.newFoldCP: isFlatFoldable -> foldWithoutOverlap -> optional
    /// foldWithOverlap -> crossLineManager.getNew. Returns false and leaves `lastFoldError`
    /// set when the pattern cannot be folded.
    @discardableResult
    public func prepareFold() -> Bool {
        lastFoldError = nil
        guard cp.isFlatFoldable() else {
            lastFoldError = PaintStrings.foldError
            return false
        }
        foldedModel.foldWithoutOverlap(cp)
        if settings.foldOverlap {
            foldedModel.foldWithOverlap()
        }
        crossLineManager.getNew(foldedModel)
        // A locally Kawasaki/Maekawa-valid pattern can still be globally non-flat-foldable;
        // the Android app renders such models as a pile of inconsistent layers. Detect it
        // (face transform vs valueAfterFold) and refuse instead of showing chaos.
        if !Self.isFoldedModelConsistent(foldedModel) {
            lastFoldError = PaintStrings.foldError
            return false
        }
        cp.clearCheckData()
        return true
    }

    public private(set) var lastFoldError: String?

    /// Port of the JS `isFoldedModelConsistent` guard in paint.js.
    private static func isFoldedModelConsistent(_ fm: FoldedModel) -> Bool {
        let tolerance = 5e-3
        for face in fm.mFaces {
            let matrix = face.transformMatrix
            let m = matrix.map { Double($0) }
            guard m.count >= 16 else { continue }
            for edge in face.halfEdges {
                let vertex = edge.start
                guard let afterFold = vertex.valueAfterFold else { continue }
                let px = m[0] * vertex.x + m[4] * vertex.y + m[12]
                let py = m[1] * vertex.x + m[5] * vertex.y + m[13]
                let dx = px - afterFold.x
                let dy = py - afterFold.y
                if dx * dx + dy * dy > tolerance * tolerance { return false }
            }
        }
        return true
    }

    // MARK: - Fragment switching (editor.js `showFragment`)

    public func setFragment(_ next: EditorFragment) {
        guard fragment != next else { return }
        fragment = next
    }

    // MARK: - Modify / history notifications

    public func markModified() {
        cp.modified = true
        objectWillChange.send()
    }

    /// Called by the paint driver after a history branch was created / undo / redo.
    public func contentChanged() {
        cp.modified = true
        revision &+= 1
        refreshUndoRedo()
        onContentChanged?()
    }

    public func refreshUndoRedo() {
        let canUndoNow = cp.historyManager.hasUndo()
        let canRedoNow = cp.historyManager.hasRedo()
        if canUndoNow != canUndo { canUndo = canUndoNow }
        if canRedoNow != canRedo { canRedo = canRedoNow }
    }

    public func undo() -> Bool {
        guard cp.historyManager.hasUndo() else { return false }
        cp.historyManager.undo(cp)
        contentChanged()
        return true
    }

    public func redo() -> Bool {
        guard cp.historyManager.hasRedo() else { return false }
        cp.historyManager.redo(cp)
        contentChanged()
        return true
    }

    // MARK: - Save / exit (EditorActivity)

    public var projectFileExists: Bool {
        store.projectExists(name: srcFilenameNoExt)
    }

    /// EditorActivity.cleanAndExit(): delete temp, clear prefs, reset data, pop to Projects.
    public func cleanAndExit() {
        guard !closed else { return }
        closed = true
        stateMachineManager.resetMachine()
        cp.modified = false
        cp.clearAll()
        store.deleteTempSave()
        prefs.clear()
        onClosed?()
    }

    /// `saveChanges(File, thumbFile)`: OPXC + 180px thumbnail, then cleanAndExit.
    private func saveChanges(name: String) {
        let projectBytes = OripaIO.exportOpxc(cp)
        let thumb = CoreRenderBridge.renderThumbnail(cp: cp)
        do {
            try store.write(name: name, opxc: projectBytes, thumbPNG: thumb)
        } catch {
            app.toast.show(PaintStrings.downloadFail)
            return
        }
        cleanAndExit()
    }

    public func saveChangesToCurrent() {
        saveChanges(name: srcFilenameNoExt)
    }

    /// DialogResponder.OnSaveOption.saveChangesToCopy(): `-copy`, `-copy-copy`, …
    public func saveChangesToCopy() {
        let copyName = store.copyName(base: srcFilenameNoExt)
        saveChanges(name: copyName)
    }

    public func discardChanges() {
        cleanAndExit()
    }

    /// EditorActivity.onCloseProject(): unmodified -> exit; modified -> save dialogs.
    public func closeProject() {
        guard !closed, !exitDialogOpen else { return }
        guard cp.modified else {
            cleanAndExit()
            return
        }
        let host = self as SaveDialogHost
        let dialog = SaveDialog.confirmExit(app.dialogs, host: host, isModified: cp.modified)
        exitDialogOpen = dialog != nil
    }

    // MARK: - Temp autosave (EditorActivity.onStop)

    /// `platform.fs.writeTemp(exportOpxc(cp))` when modified.
    public func autosaveTemp() {
        guard !closed, cp.modified else { return }
        let bytes = OripaIO.exportOpxc(cp)
        let meta = TempSaveMeta(projectName: srcIsInternal ? srcFilenameNoExt : nil,
                                srcFilenameNoExt: srcFilenameNoExt,
                                srcIsInternal: srcIsInternal,
                                fragment: fragment.rawValue,
                                modified: cp.modified)
        store.writeTempSave(bytes, meta: meta)
    }

    /// `EditorScreen.leave()`: screen torn down outside cleanAndExit — mark closed so a
    /// later cleanAndExit/back does not run twice.
    public func markClosedForTeardown() {
        closed = true
    }

    /// `PaintCpFragment.resume()` after returning from Settings.
    public func reloadSettings() {
        settings = EditorPrefs.read(prefs)
    }

    /// Export CP dialog source name.
    public var exportBaseName: String { srcFilenameNoExt }
}

// MARK: - SaveDialogHost

extension EditorSession: SaveDialogHost {
    public func saveDialogClosed() {
        exitDialogOpen = false
    }
}

// MARK: - ExportCPHost

extension EditorSession: ExportCPHost {
    public var exportBaseNameForDialog: String { srcFilenameNoExt }

    public func exportSVGData() -> Data? {
        OripaIO.exportSvgData(cp)
    }

    public func exportOPXData() -> Data? {
        OripaIO.exportOpx(cp)
    }

    public func exportCPData() -> Data? {
        OripaIO.exportCp(cp)
    }

    public func exportPNGData(sizePx: Int) -> Data? {
        let options = CPPNGExportOptions(background: CanvasRGB(1.0, 1.0, 1.0),
                                         showGrid: settings.showGrid,
                                         showFlatLines: settings.showFlatLines,
                                         dashed: settings.useDashedLines,
                                         thumbnail: false,
                                         lineWidthScale: 2.0)
        return CoreRenderBridge.renderPNG(cp: cp, width: sizePx, height: sizePx, options: options)
    }
}
