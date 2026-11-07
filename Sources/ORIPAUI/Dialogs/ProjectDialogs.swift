// Project file dialogs — ports of the Android dialog fragments:
//   ProjectRenameDialogFragment          "Rename file?" / Filename / Rename
//   ProjectCopyDialogFragment            "Make a copy?" / Copy
//   ProjectDeleteDialogFragment          "Delete file?" / Delete
//   ProjectDeleteMultipleDialogFragment  "Delete %d file(s)?" / Delete All
//   ErrorDialogFragment                  "Error" / message / OK
//   text/FilenameInputFilter             letters/digits/_/- only
//
// Strings are the exact `res/values/strings.xml` values (see the ui-projects report);
// result snackbars mirror `ProjectsActivity` / `PreviewCreasePatternActivity`:
//   * rename from projects: "File renamed" on success, "Error renaming file" on failure;
//   * rename from preview (silent): no snackbar here, the caller shows it after popping;
//   * copy: only "Error copying file" (no success snackbar — ProjectsActivity);
//   * delete: only "Error deleting file";
//   * imports: "Error copying file".
import Foundation
import SwiftUI
import ORIPACore

/// Project dialog strings — exact `res/values/strings.xml` resources.
public enum ProjectDialogStrings {
    public static let renameTitle = "Rename file?"                    // dialog_file_rename_title
    public static let renameHint = "Filename"                         // dialog_file_rename_edit_text_hint
    public static let renamePositive = "Rename"                       // dialog_file_rename_positive_button
    public static let copyTitle = "Make a copy?"                      // dialog_file_copy_title
    public static let copyPositive = "Copy"                           // dialog_file_copy_positive_button
    public static let deleteTitle = "Delete file?"                    // dialog_file_delete_title
    public static let deletePositive = "Delete"                       // dialog_file_delete_positive_button
    public static let deleteMultiplePositive = "Delete All"           // dialog_file_delete_multiple_positive_button
    public static let cancel = "Cancel"                               // android.R.string.cancel
    public static let ok = "OK"                                       // android.R.string.ok
    public static let errorTitle = "Error"                            // android.R.string.dialog_alert_title

    public static let renameSuccess = "File renamed"                  // message_file_rename_success_text
    public static let renameError = "Error renaming file"             // message_file_rename_error_text
    public static let copySuccess = "File copied"                     // message_file_copy_success_text
    public static let copyError = "Error copying file"                // message_file_copy_error_text
    public static let deleteSuccess = "File deleted"                  // message_file_delete_success_text
    public static let deleteError = "Error deleting file"             // message_file_delete_error_text
    public static let itemSelected = "Item selected"                  // item_selected
    public static let overflow = "Overflow"                           // overflow

    /// `plurals.dialog_file_delete_multiple_title`: "Delete 1 file?" / "Delete N files?".
    public static func deleteMultipleTitle(count: Int) -> String {
        count == 1 ? "Delete 1 file?" : "Delete \(count) files?"
    }

    /// `plurals.projects_second_bar_title`: "%d selected" (only the "other" quantity exists).
    public static func selectedTitle(count: Int) -> String {
        "\(count) selected"
    }

    /// `plurals.projects_title`: "%d File" / "%d Files".
    public static func projectsTitle(count: Int) -> String {
        "\(count) File" + (count == 1 ? "" : "s")
    }

    // Projects screen strings (`projects_action_bar.xml`, `projects_second_bar.xml`,
    // `preview_cp_action_bar.xml` and the menu plurals).
    public static let about = "About"                               // projects_action_about_title
    public static let importTitle = "Import"                        // projects_action_import_title
    public static let sortByName = "Sort by Name"                   // projects_action_sort_name_title
    public static let sortByLastModified = "Sort by Last Modified"  // projects_action_sort_modified_title
    public static let viewGrid = "View as Grid"                     // projects_action_view_grid_title
    public static let viewGridCondensed = "View Grid"               // ...titleCondensed
    public static let viewList = "View as List"                     // projects_action_view_list_title
    public static let viewListCondensed = "View List"               // ...titleCondensed
    public static let newFileTitle = "New File"                     // projects_fab_description
    public static let itemPreview = "Preview Image"                 // projects_item_preview_description
    public static let delete = "Delete"                             // projects_second_bar_delete_title
    public static let rename = "Rename"                             // preview_action_rename_title
    public static let copy = "Make a copy"                          // preview_action_copy_title
    public static let remove = "Delete"                             // preview_action_delete_title
    public static let navigateUp = "Navigate up"                    // abc_action_bar_up_description
    public static let moreOptions = "More options"                  // overflow content description
}

/// Project file dialog actions.
@MainActor
public enum ProjectDialogs {

    /// `ProjectRenameDialogFragment`: text dialog with `FilenameInputFilter` sanitizing.
    ///
    /// - Parameters:
    ///   - silent: skip the success snackbar (preview screen shows it after popping).
    ///   - onSuccess: called with the final (possibly uniquified) project name.
    public static func rename(app: AppModel,
                              name: String,
                              silent: Bool = false,
                              onSuccess: ((String) -> Void)? = nil) {
        app.dialogs.textDialog(
            title: ProjectDialogStrings.renameTitle,
            icon: "ic_rename_dark_v2_24px",
            initialValue: name,
            hint: ProjectDialogStrings.renameHint,
            sanitize: { ProjectStore.sanitizeFilename($0) },
            positiveText: ProjectDialogStrings.renamePositive,
            negativeText: ProjectDialogStrings.cancel
        ) { entered in
            // doPositiveClick(): empty or unchanged name is a no-op (the dialog closes).
            guard let entered, !entered.isEmpty, entered != name else { return }
            do {
                let newName = try app.store.rename(oldName: name, to: entered)
                if !silent {
                    app.toast.show(ProjectDialogStrings.renameSuccess)
                }
                onSuccess?(newName)
            } catch {
                app.toast.show(ProjectDialogStrings.renameError)
            }
        }
    }

    /// `ProjectCopyDialogFragment`: "Make a copy?" / Cancel / Copy.
    public static func copy(app: AppModel,
                            name: String,
                            onSuccess: ((String) -> Void)? = nil) {
        app.dialogs.show(OrDialogSpec(
            title: ProjectDialogStrings.copyTitle,
            icon: "ic_content_copy_dark_24dp",
            buttons: [
                OrDialogButton(ProjectDialogStrings.cancel),
                OrDialogButton(ProjectDialogStrings.copyPositive, primary: true) {
                    do {
                        let newName = try app.store.copy(name: name)
                        onSuccess?(newName)
                    } catch {
                        app.toast.show(ProjectDialogStrings.copyError)
                    }
                    return true
                },
            ]
        ))
    }

    /// `ProjectDeleteDialogFragment`: "Delete file?" / Cancel / Delete.
    public static func deleteOne(app: AppModel,
                                 name: String,
                                 onSuccess: (() -> Void)? = nil) {
        app.dialogs.show(OrDialogSpec(
            title: ProjectDialogStrings.deleteTitle,
            icon: "ic_delete_dark_24dp",
            buttons: [
                OrDialogButton(ProjectDialogStrings.cancel),
                OrDialogButton(ProjectDialogStrings.deletePositive, primary: true) {
                    do {
                        try app.store.delete(name: name)
                        onSuccess?()
                    } catch {
                        app.toast.show(ProjectDialogStrings.deleteError)
                    }
                    return true
                },
            ]
        ))
    }

    /// `ProjectDeleteMultipleDialogFragment`: "Delete %d file(s)?" / Cancel / Delete All.
    public static func deleteMultiple(app: AppModel,
                                      count: Int,
                                      onConfirm: @escaping () -> Void) {
        app.dialogs.show(OrDialogSpec(
            title: ProjectDialogStrings.deleteMultipleTitle(count: count),
            icon: "ic_delete_dark_24dp",
            buttons: [
                OrDialogButton(ProjectDialogStrings.cancel),
                OrDialogButton(ProjectDialogStrings.deleteMultiplePositive, primary: true) {
                    onConfirm()
                    return true
                },
            ]
        ))
    }

    /// `ErrorDialogFragment` of the projects flow (title "Error", error_outline icon, OK).
    public static func showError(app: AppModel, message: String) {
        app.dialogs.show(OrDialogSpec(
            title: ProjectDialogStrings.errorTitle,
            icon: "ic_error_outline_dark_24dp",
            content: AnyView(OrDialogText(message)),
            buttons: [OrDialogButton(ProjectDialogStrings.ok, primary: true)]
        ))
    }
}
