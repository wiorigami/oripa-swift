// Shared dialogs used by several screens (editor / fold / shell).
//
// Port of the shared AlertDialog helpers of `src/js/ui/dialogs/error.js`:
//   * `ErrorDialogFragment` — title "Attention", error_outline icon, message, OK;
//   * the "Feature under construction" dialog used when a ported screen is unavailable;
//   * Android-style confirm dialogs (Cancel / positive).
import SwiftUI

/// Shared dialog helpers (AlertDialog chrome: icon + title + buttons).
@MainActor
public enum CommonDialogs {

    /// `ErrorDialogFragment`: title "Attention", error icon, OK.
    public static func showError(app: AppModel, message: String) {
        app.dialogs.show(OrDialogSpec(
            title: CommonDialogStrings.attention,
            icon: "ic_error_outline_dark_24dp",
            content: AnyView(OrDialogText(message)),
            buttons: [OrDialogButton(CommonDialogStrings.ok, primary: true)],
            width: 280,
            actionsTopPadding: 20
        ))
    }

    /// "Feature under construction.\n\nThank you for your patience!" (feature_under_construction).
    public static func showFeatureUnavailable(app: AppModel, detail: String? = nil) {
        var message = "Feature under construction.\n\nThank you for your patience!"
        if let detail, !detail.isEmpty {
            message += "\n\n" + detail
        }
        app.dialogs.show(OrDialogSpec(
            title: nil,
            content: AnyView(OrDialogText(message)),
            buttons: [OrDialogButton(CommonDialogStrings.ok, primary: true)],
            width: 280
        ))
    }

    /// `M.confirm(title, text, positiveText, negativeText, cb)`.
    public static func confirm(app: AppModel,
                               title: String,
                               message: String,
                               positiveText: String = CommonDialogStrings.ok,
                               negativeText: String = CommonDialogStrings.cancel,
                               onResult: ((Bool) -> Void)? = nil) {
        app.dialogs.confirm(title: title,
                            text: message,
                            positiveText: positiveText,
                            negativeText: negativeText,
                            onResult: onResult)
    }
}
