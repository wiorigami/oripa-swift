// "Save changes?" dialogs shown when leaving the editor.
//
// Port of `oripa-port/src/js/ui/dialogs/save.js`:
//   SaveExistingDialogFragment (project file already on disk):
//       single choice "Save to current file" / "Save to new file"
//   SaveNewDialogFragment (new project): Save / Discard / Cancel
//   EditorActivity.onCloseProject(): when to show which dialog.
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

private final class SaveChoiceModel: ObservableObject {
    @Published var selected: Int = 0

    init(selected: Int) { self.selected = selected }
}

private struct SaveExistingChoiceView: View {
    @ObservedObject var model: SaveChoiceModel

    var body: some View {
        VStack(spacing: 0) {
            choiceRow(index: 0, label: PaintStrings.saveCurrent)
            choiceRow(index: 1, label: PaintStrings.saveNew)
        }
        .padding(.vertical, 4)
    }

    private func choiceRow(index: Int, label: String) -> some View {
        Button {
            model.selected = index
        } label: {
            HStack(spacing: 16) {
                MaterialIcon("ic_save_dark_24dp", size: 24, tint: OrTheme.iconActive)
                Text(label)
                    .font(OrTheme.menuItem())
                    .foregroundColor(OrTheme.textPrimary)
                Spacer(minLength: 8)
                OrRadioMark(isChecked: model.selected == index)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
public enum SaveDialog {
    /// SaveExistingDialogFragment: single choice + Cancel / Discard / Save.
    @discardableResult
    public static func showExisting(_ dialogs: DialogCenter, host: SaveDialogHost) -> OrDialogSpec? {
        guard dialogs.top == nil || dialogs.top?.title != PaintStrings.saveChangesTitle else { return nil }
        let model = SaveChoiceModel(selected: 0)
        let spec = OrDialogSpec(
            title: PaintStrings.saveChangesTitle,
            icon: "ic_save_dark_24dp",
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
            onClose: { host.saveDialogClosed() })
        dialogs.show(spec)
        return spec
    }

    /// SaveNewDialogFragment (no extra body: title + buttons like Android).
    @discardableResult
    public static func showNew(_ dialogs: DialogCenter, host: SaveDialogHost) -> OrDialogSpec? {
        guard dialogs.top == nil || dialogs.top?.title != PaintStrings.saveChangesTitle else { return nil }
        let spec = OrDialogSpec(
            title: PaintStrings.saveChangesTitle,
            icon: "ic_save_dark_24dp",
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
            onClose: { host.saveDialogClosed() })
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
