// Number text dialogs for the paint by-value column.
//
// Port of the inline `showNumberTextDialog` in `oripa-port/src/js/ui/fragments/paint.js`
// (Android `EditTextNumberDialogFragment`):
//   title "Set Angle (Degrees)" / hint "Degrees"  (paint_top_add_by_value_dialog_angle_*)
//   title "Set Length"          / hint "Length"   (paint_top_add_by_value_dialog_length_*)
// OK parses the text; an empty value is ignored (the JS `if (text === "") return;`).
//
// The reference dialog is `D.material.dialog({ icon, title, content: input, buttons })`:
// a 24 dp heading icon + 20/28 heading inside the 24 dp dialog content, then the single
// underlined 16 sp text field, then CANCEL / OK. The card is content-sized at the
// Material AlertDialog min width (280 dp).
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
        let model = OrTextInputModel(
            text: initialValue,
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
            })

        func submit(_ text: String?) {
            guard let text else { return }
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            onResult(PaintStrings.parseNumber(trimmed))
        }

        let content = VStack(spacing: 0) {
            if let icon {
                EditorDialogHeading(icon: icon, title: title)
            } else {
                Text(title)
                    .font(OrTheme.dialogTitle())
                    .foregroundColor(OrTheme.textPrimary)
                    .frame(minHeight: 28, alignment: .leading)
                    .padding(.bottom, 10)
            }
            OrTextInputField(model: model)
        }

        model.onSubmit = {
            submit(model.text)
            dialogs.closeTop()
        }

        dialogs.show(OrDialogSpec(
            title: nil,
            icon: nil,
            content: AnyView(content),
            buttons: [
                OrDialogButton(PaintStrings.cancel),
                OrDialogButton(PaintStrings.ok, primary: true) {
                    submit(model.text)
                    return true
                },
            ],
            cancelable: true,
            width: 280))
        return model
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
