// "Save changes?" dialogs shown when leaving the editor.
//
// Port of `oripa-port/src/js/ui/dialogs/save.js`:
//   SaveExistingDialogFragment (project file already on disk):
//       single choice "Save to current file" / "Save to new file"
//   SaveNewDialogFragment (new project): title + Save / Discard / Cancel
//   EditorActivity.onCloseProject(): when to show which dialog.
//
// Reference chrome (`M.dialog` + `dialogs/error.js` `D.material.dialog`): 24 dp heading
// icon, 20/28 medium title, content-driven card at the 280 dp AlertDialog min width,
// 48 dp single-choice rows with a trailing Material radio, uppercase CANCEL / DISCARD /
// SAVE text buttons (SAVE is the accent positive button).
//
// The dialogs are presented through the shared `DialogCenter` (ui-shell) and drive the
// session through `SaveDialogHost` so this file has no core-model dependency.
import Foundation
import SwiftUI

/// The editor session surface used by the save/exit dialogs.
@MainActor
public protocol SaveDialogHost: AnyObject {
    /// `session.projectFileExists()` — `project_data/<name>` exists on disk.
    var projectFileExists: Bool { get }
    /// `DialogResponder.OnSaveOption.saveChangesToCurrent()`.
    func saveChangesToCurrent()
    /// `DialogResponder.OnSaveOption.saveChangesToCopy()` (`-copy`, `-copy-copy`, …).
    func saveChangesToCopy()
    /// `DialogResponder.OnSaveOption.discardChanges()`.
    func discardChanges()
    /// `session._onSaveDialogClosed`.
    func saveDialogClosed()
}

@MainActor
private final class SaveChoiceModel: ObservableObject {
    @Published var selected: Int = 0

    init(selected: Int) { self.selected = selected }
}

/// Reference `SaveExistingDialogFragment` body: two 48 dp single-choice rows, no icons.
private struct SaveExistingChoiceView: View {
    @ObservedObject var model: SaveChoiceModel

    var body: some View {
        VStack(spacing: 0) {
            EditorDialogHeading(icon: "ic_save_dark_24dp",
                                title: PaintStrings.saveChangesTitle)
            EditorDialogChoiceRow(label: PaintStrings.saveCurrent,
                                  isChecked: model.selected == 0) {
                model.selected = 0
            }
            EditorDialogChoiceRow(label: PaintStrings.saveNew,
                                  isChecked: model.selected == 1) {
                model.selected = 1
            }
        }
    }
}

/// Reference `SaveNewDialogFragment` body: title only.
private struct SaveNewHeadingView: View {
    var body: some View {
        EditorDialogHeading(icon: "ic_save_dark_24dp",
                            title: PaintStrings.saveChangesTitle)
    }
}

@MainActor
public enum SaveDialog {
    /// Material AlertDialog min width (the JS `M.dialog` has no explicit width here).
    private static let dialogWidth: CGFloat = 280

    /// Identity holder for the close closure (avoids the spec capturing itself).
    private final class DialogToken {
        var specID: UUID?
    }

    /// Specs of the save dialogs currently on screen; the JS/Android fragments guard
    /// against showing a second copy while one is open (`EditorSession.closeProject`
    /// re-entrancy). A set keeps independent windows / dialog centers working.
    private static var activeSpecIDs: Set<UUID> = []

    private static func isAlreadyPresented(_ dialogs: DialogCenter) -> Bool {
        dialogs.stack.contains { activeSpecIDs.contains($0.id) }
    }

    /// SaveExistingDialogFragment: single choice + Cancel / Discard / Save.
    @discardableResult
    public static func showExisting(_ dialogs: DialogCenter, host: SaveDialogHost) -> OrDialogSpec? {
        guard !isAlreadyPresented(dialogs) else { return nil }
        let model = SaveChoiceModel(selected: 0)
        let token = DialogToken()
        let spec = OrDialogSpec(
            title: nil,
            icon: nil,
            content: AnyView(SaveExistingChoiceView(model: model)),
            buttons: [
                OrDialogButton(PaintStrings.cancel),
                OrDialogButton(PaintStrings.discard) {
                    host.discardChanges()
                    return true
                },
                OrDialogButton(PaintStrings.save, primary: true) {
                    let toCopy = model.selected == 1
                    if toCopy {
                        host.saveChangesToCopy()
                    } else {
                        host.saveChangesToCurrent()
                    }
                    return true
                },
            ],
            cancelable: true,
            width: dialogWidth,
            onClose: {
                if let id = token.specID { activeSpecIDs.remove(id) }
                host.saveDialogClosed()
            })
        token.specID = spec.id
        activeSpecIDs.insert(spec.id)
        dialogs.show(spec)
        return spec
    }

    /// SaveNewDialogFragment (no extra body: title + buttons like Android).
    @discardableResult
    public static func showNew(_ dialogs: DialogCenter, host: SaveDialogHost) -> OrDialogSpec? {
        guard !isAlreadyPresented(dialogs) else { return nil }
        let token = DialogToken()
        let spec = OrDialogSpec(
            title: nil,
            icon: nil,
            content: AnyView(SaveNewHeadingView()),
            buttons: [
                OrDialogButton(PaintStrings.cancel),
                OrDialogButton(PaintStrings.discard) {
                    host.discardChanges()
                    return true
                },
                OrDialogButton(PaintStrings.save, primary: true) {
                    host.saveChangesToCurrent()
                    return true
                },
            ],
            cancelable: true,
            width: dialogWidth,
            onClose: {
                if let id = token.specID { activeSpecIDs.remove(id) }
                host.saveDialogClosed()
            })
        token.specID = spec.id
        activeSpecIDs.insert(spec.id)
        dialogs.show(spec)
        return spec
    }

    /// EditorActivity.onCloseProject(): unmodified → cleanAndExit; project file exists →
    /// SaveExisting; otherwise → SaveNew. Returns the presented dialog (nil if none).
    @discardableResult
    public static func confirmExit(_ dialogs: DialogCenter, host: SaveDialogHost,
                                   isModified: Bool) -> OrDialogSpec? {
        if !isModified {
            host.discardChanges()
            return nil
        }
        if host.projectFileExists {
            return showExisting(dialogs, host: host)
        }
        return showNew(dialogs, host: host)
    }
}
