// Editor session boundary between the shell (ui-shell) and the editor screen (ui-canvas).
//
// Port of the JS port's retained `ProjectDataFragment` + `EditorActivity` helper object
// (`src/js/ui/screens/editor.js`, `createSession`). The editor screen owns the concrete
// session; every editor child fragment (paint / check / fold) consumes this protocol only.
//
// Owned by ui-shell (contract §5.2) — **additive changes only**; message the Lead and the
// affected owners first when a required member must change.
import Foundation
import ORIPACore

@MainActor
public protocol EditorSessionProtocol: AnyObject {
    /// Shared crease pattern (`ProjectDataFragment.mCreasePattern`).
    var cp: CreasePattern { get }
    /// Folded model built by `prepareFold()` (`ProjectDataFragment.mFoldedModel`).
    var foldedModel: FoldedModel { get }
    /// Cut-line manager of the fold view (`ProjectDataFragment.mCrossLineManager`).
    var crossLineManager: CrossLineManager { get }
    /// Android default SharedPreferences bridge (`ORIPA.platform.prefs`).
    var prefs: Preferences { get }
    /// File name without extension proposed by the save dialog (`srcFilenameNoExt`).
    var srcFilenameNoExt: String { get }
    /// `SRC_IS_INTERNAL` — true when the session belongs to an internal `project_data` file.
    var srcIsInternal: Bool { get }
    /// `cp.modified` mirror used by the save/exit dialogs.
    var modified: Bool { get }

    /// `EditorActivity.returnToPaintFragment()`: clear the folded model/cross lines/check data
    /// and show the paint fragment.
    func returnToPaint()
    /// `EditorActivity.onCloseProject()`: close the project honouring unsaved changes
    /// (save existing / save new / discard dialogs); ends in `cleanAndExit()` or keeps open.
    func requestCloseProject()
    /// Check fragment entry: `cp.isFlatFoldable()` (returns true when foldable).
    @discardableResult
    func runFlatFoldabilityCheck() -> Bool
    /// Fold fragment entry: fold the CP like `PaintCpFragment.newFoldCPIntent`
    /// (`FoldSettingData.setNewFoldModel`); false when folding is not possible.
    @discardableResult
    func prepareFold() -> Bool
}
