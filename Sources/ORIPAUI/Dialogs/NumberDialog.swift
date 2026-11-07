// Number text dialogs for the paint by-value column.
//
// Port of the inline `showNumberTextDialog` in `oripa-port/src/js/ui/fragments/paint.js`
// (Android `EditTextNumberDialogFragment`):
//   title "Set Angle (Degrees)" / hint "Degrees"  (paint_top_add_by_value_dialog_angle_*)
//   title "Set Length"          / hint "Length"   (paint_top_add_by_value_dialog_length_*)
// OK parses the text; an empty value is ignored (the JS `if (text === "") return;`).
import Foundation
import SwiftUI

@MainActor
public enum NumberDialog {
    /// Shows the Material text-input dialog; `onResult` is called with the parsed number,
    /// or not called at all when the user cancels / enters nothing.
    @discardableResult
    public static func show(_ dialogs: DialogCenter,
                            title: String,
                            icon: String?,
                            hint: String,
                            initialValue: String,
                            onResult: @escaping (Double) -> Void) -> OrTextInputModel {
        dialogs.textDialog(title: title,
                           icon: icon,
                           initialValue: initialValue,
                           hint: hint,
                           sanitize: { text in
                               // Decimal keyboard equivalent: digits, one separator, optional minus.
                               var out = ""
                               var hasSeparator = false
                               for ch in text {
                                   if ch.isNumber {
                                       out.append(ch)
                                   } else if (ch == "." || ch == ",") && !hasSeparator {
                                       out.append(ch)
                                       hasSeparator = true
                                   } else if ch == "-" && out.isEmpty {
                                       out.append(ch)
                                   }
                               }
                               return out
                           },
                           positiveText: PaintStrings.ok,
                           negativeText: PaintStrings.cancel,
                           onResult: { text in
                               guard let text else { return }
                               let trimmed = text.trimmingCharacters(in: .whitespaces)
                               guard !trimmed.isEmpty else { return }
                               onResult(PaintStrings.parseNumber(trimmed))
                           })
    }

    /// Angle dialog: the value is reduced modulo 360 like `parseNumberText(text) % 360`.
    @discardableResult
    public static func showAngle(_ dialogs: DialogCenter,
                                 initialValue: Double,
                                 onResult: @escaping (Double) -> Void) -> OrTextInputModel {
        show(dialogs,
             title: PaintStrings.angleDialogTitle,
             icon: "ic_angle_dark_v2_24px",
             hint: PaintStrings.angleDialogHint,
             initialValue: PaintStrings.formatNumber(initialValue),
             onResult: { value in onResult(value.truncatingRemainder(dividingBy: 360)) })
    }

    /// Length dialog.
    @discardableResult
    public static func showLength(_ dialogs: DialogCenter,
                                  initialValue: Double,
                                  onResult: @escaping (Double) -> Void) -> OrTextInputModel {
        show(dialogs,
             title: PaintStrings.lengthDialogTitle,
             icon: "ic_straighten_dark_24dp",
             hint: PaintStrings.lengthDialogHint,
             initialValue: PaintStrings.formatNumber(initialValue),
             onResult: onResult)
    }
}
