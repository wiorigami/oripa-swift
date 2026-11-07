// Port of `oripa-port/src/js/ui/dialogs/fold_settings.js` — the three Android fold
// settings AlertDialogs (`editor/FoldCpCrossLineSettingsDialogFragment`,
// `editor/FoldCpOverlapSettingsDialogFragment`, `editor/FoldCpXraySettingsDialogFragment`).
//
// All three use the shared Material AlertDialog chrome (title "Settings" + gear icon,
// fold-local `FoldDialogCard`). Preferences are read/written by the caller (the fold
// screen), exactly like the JS dialogs read `ORIPA.platform.prefs`; the dialogs report
// every live change through callbacks so the fold view can update the renderer while the
// dialog is open (Android live preview).
import SwiftUI
import ORIPACore

// MARK: - Preference keys / defaults

/// Android preference keys used by the fold screen (exact SharedPreferences strings).
public enum FoldPref {
    // FoldCpFragment
    public static let xrayStyleWire = "FoldCpFragment.xrayStyleWire"
    public static let crossOneFingerMove = "FoldCpFragment.crossOneFingerMove"
    // FoldCpOverlapSettingsDialogFragment
    public static let overlapFlip = "FoldCpOverlapSettingsDialogFragment.prefKeyFlip"
    public static let overlapFrontColor = "FoldCpOverlapSettingsDialogFragment.prefKeyFrontColor"
    public static let overlapBackColor = "FoldCpOverlapSettingsDialogFragment.prefKeyBackColor"
    public static let overlapLineColor = "FoldCpOverlapSettingsDialogFragment.prefKeyLineColor"
    // drawing preferences (PaintCpSettingsActivity / pref_paint_cp_settings.xml)
    public static let overlapEnabled = "paint_pref_fold_overlap"
    public static let overlapShadow = "paint_pref_fold_overlap_shadow"

    /// JS-style aliases (`fold.PREF_KEY_*` / `dialogs.FOLD_PREF`).
    public static let XRAY_STYLE_WIRE = xrayStyleWire
    public static let CROSS_ONE_FINGER_MOVE = crossOneFingerMove
    public static let OVERLAP_FLIP = overlapFlip
    public static let OVERLAP_FRONT_COLOR = overlapFrontColor
    public static let OVERLAP_BACK_COLOR = overlapBackColor
    public static let OVERLAP_LINE_COLOR = overlapLineColor
    public static let OVERLAP_ENABLED = overlapEnabled
    public static let OVERLAP_SHADOW = overlapShadow
}

/// `FoldCpOverlapSettingsDialogFragment.defaultPrefValue*` (Android colour ints).
public enum FoldOverlapDefaults {
    public static let flip = false
    /// 0xFFFF91AE (`-28242` in the Android int preferences).
    public static let frontColor: UInt32 = 0xFFFF_91AE
    /// 0xFF00B7D9 (`-16730151`).
    public static let backColor: UInt32 = 0xFF00_B7D9
    /// 0xFF505050 (`-11513776`).
    public static let lineColor: UInt32 = 0xFF50_5050

    /// The same defaults as signed Java ints (the values stored in SharedPreferences).
    public static let frontColorPref = -28242
    public static let backColorPref = -16730151
    public static let lineColorPref = -11513776

    // JS-style aliases.
    public static let FLIP = flip
    public static let FRONT_COLOR = frontColor
    public static let BACK_COLOR = backColor
    public static let LINE_COLOR = lineColor

    /// Android stores colour ints as signed Java ints; `0xAARRGGBB` <-> Int(bitPattern:).
    public static func color(fromPref value: Int) -> UInt32 {
        UInt32(bitPattern: Int32(truncatingIfNeeded: value))
    }

    /// `0xAARRGGBB` -> the signed Java int written to the preferences.
    public static func prefInt(fromColor color: UInt32) -> Int {
        Int(Int32(bitPattern: color))
    }
}

/// `R.array.fold_action_spinner_labels` / `R.array.fold_dialog_xray_settings`.
public enum FoldStrings {
    public static let spinnerLabels = ["X-Ray / Wireframe", "Overlap [BETA]", "Cut Line"]
    public static let xraySettingsOptions = ["Use wireframe mode"]
    public static let settingsTitle = "Settings"
    public static let exportTitle = "Export Model"
    public static let pngOptionsTitle = "PNG Options"
    public static let imageSizeLabel = "Image size (pixels):"
    public static let downloadCompleteText = "Download complete"
    public static let downloadFailedText = "Download failed"
    public static let downloadSuccessAction = "View folder"
    public static let moveCutLineDescription = "Move Cut Line"
    public static let rotateCutLineDescription = "Rotate Cut Line"
    public static let wireframeText = "Use wireframe mode"
    public static let showButtonsText = "Show move/rotate buttons"
    public static let flipText = "Flip"
    public static let frontColorTitle = "Front Color"
    public static let backColorTitle = "Back Color"
    public static let lineColorTitle = "Line Color"
    public static let positionLabel = "Position"
    public static let angleLabel = "Angle"
}

// MARK: - X-Ray settings dialog (multi-choice list)

/// `FoldCpXraySettingsDialogFragment`: single multi-choice row "Use wireframe mode"; each
/// tap applies + persists immediately, no dialog buttons.
struct FoldXraySettingsDialog: View {
    let initialWireframe: Bool
    /// Live toggle: the fold screen persists `FoldPref.xrayStyleWire` and redraws.
    let onWireframe: (Bool) -> Void
    let onDismiss: () -> Void

    @State private var wireframe: Bool

    init(initialWireframe: Bool,
         onWireframe: @escaping (Bool) -> Void,
         onDismiss: @escaping () -> Void) {
        self.initialWireframe = initialWireframe
        self.onWireframe = onWireframe
        self.onDismiss = onDismiss
        _wireframe = State(initialValue: initialWireframe)
    }

    var body: some View {
        FoldDialogScrim(onDismiss: onDismiss) {
            FoldDialogCard(title: FoldStrings.settingsTitle,
                           icon: "ic_settings_dark_24dp",
                           contentPadding: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0),
                           buttons: []) {
                FoldMultiChoiceRow(label: FoldStrings.wireframeText, isOn: wireframe) {
                    wireframe.toggle()
                    onWireframe(wireframe)
                }
            }
            .frame(maxWidth: 360)
        }
    }
}

// MARK: - Overlap settings dialog (flip + three colour pickers)

/// `FoldCpOverlapSettingsDialogFragment`: flip checkbox + Front/Back/Line colour picker
/// rows. Changes persist immediately (no dialog buttons; dismiss by tapping outside).
struct FoldOverlapSettingsDialog: View {
    let initialFlip: Bool
    let initialFrontColor: UInt32
    let initialBackColor: UInt32
    let initialLineColor: UInt32
    let onFlip: (Bool) -> Void
    let onColors: (UInt32, UInt32, UInt32) -> Void
    let onDismiss: () -> Void

    private enum ColorTarget: Int, Identifiable {
        case front = 1
        case back = 2
        case line = 3

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .front: return FoldStrings.frontColorTitle
            case .back: return FoldStrings.backColorTitle
            case .line: return FoldStrings.lineColorTitle
            }
        }

        var defaultColor: UInt32 {
            switch self {
            case .front: return FoldOverlapDefaults.frontColor
            case .back: return FoldOverlapDefaults.backColor
            case .line: return FoldOverlapDefaults.lineColor
            }
        }
    }

    @State private var flip: Bool
    @State private var frontColor: UInt32
    @State private var backColor: UInt32
    @State private var lineColor: UInt32
    @State private var activePicker: ColorTarget?

    init(initialFlip: Bool,
         initialFrontColor: UInt32,
         initialBackColor: UInt32,
         initialLineColor: UInt32,
         onFlip: @escaping (Bool) -> Void,
         onColors: @escaping (UInt32, UInt32, UInt32) -> Void,
         onDismiss: @escaping () -> Void) {
        self.initialFlip = initialFlip
        self.initialFrontColor = initialFrontColor
        self.initialBackColor = initialBackColor
        self.initialLineColor = initialLineColor
        self.onFlip = onFlip
        self.onColors = onColors
        self.onDismiss = onDismiss
        _flip = State(initialValue: initialFlip)
        _frontColor = State(initialValue: initialFrontColor)
        _backColor = State(initialValue: initialBackColor)
        _lineColor = State(initialValue: initialLineColor)
    }

    private func currentColor(_ target: ColorTarget) -> UInt32 {
        switch target {
        case .front: return frontColor
        case .back: return backColor
        case .line: return lineColor
        }
    }

    private func setColor(_ target: ColorTarget, _ color: UInt32) {
        switch target {
        case .front: frontColor = color
        case .back: backColor = color
        case .line: lineColor = color
        }
        onColors(frontColor, backColor, lineColor)
    }

    var body: some View {
        FoldDialogScrim(onDismiss: onDismiss) {
            ZStack {
                FoldDialogCard(title: FoldStrings.settingsTitle,
                               icon: "ic_settings_dark_24dp",
                               contentPadding: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0),
                               buttons: []) {
                    VStack(alignment: .leading, spacing: 0) {
                        FoldCheckRow(label: FoldStrings.flipText,
                                     isOn: flip,
                                     leadingPadding: 20) { newValue in
                            flip = newValue
                            onFlip(newValue)
                        }
                        ForEach([ColorTarget.front, .back, .line]) { target in
                            FoldColorPickerRow(title: target.title,
                                               currentColor: currentColor(target)) {
                                activePicker = target
                            }
                        }
                    }
                }
                .frame(maxWidth: 360)

                if let target = activePicker {
                    FoldColorPickerDialog(
                        defaultColor: target.defaultColor,
                        currentColor: currentColor(target),
                        onCancel: { activePicker = nil },
                        onOK: { color in
                            setColor(target, color)
                            activePicker = nil
                        })
                }
            }
        }
    }
}

// MARK: - Cut Line settings dialog (position/angle seekbars + checkboxes, OK/Cancel)

/// `FoldCpCrossLineSettingsDialogFragment`: Position + Angle seekbars (max
/// `CrossLine.getPositionMaxMagnitude()` / `getAngleDegMaxMagnitude()`), wireframe and
/// show-buttons checkboxes; live preview, Cancel restores the initial state (Java
/// `onCancel`), OK persists the wireframe pref and reports all values.
struct FoldCrossLineSettingsDialog: View {
    let initialAngleDeg: Int
    let initialPosition: Int
    let initialButtonVisible: Bool
    let angleDegMax: Int
    let positionMax: Int
    let wireframeInitial: Bool
    let onUpdate: (Int, Int) -> Void
    let onWireframe: (Bool) -> Void
    let onButtonVisible: (Bool) -> Void
    let onConfirm: (Int, Int, Bool) -> Void
    let onCancel: () -> Void

    @State private var angleDeg: Int
    @State private var position: Int
    @State private var wireframe: Bool
    @State private var buttonsVisible: Bool

    init(initialAngleDeg: Int,
         initialPosition: Int,
         initialButtonVisible: Bool,
         angleDegMax: Int,
         positionMax: Int,
         wireframeInitial: Bool,
         onUpdate: @escaping (Int, Int) -> Void,
         onWireframe: @escaping (Bool) -> Void,
         onButtonVisible: @escaping (Bool) -> Void,
         onConfirm: @escaping (Int, Int, Bool) -> Void,
         onCancel: @escaping () -> Void) {
        self.initialAngleDeg = initialAngleDeg
        self.initialPosition = initialPosition
        self.initialButtonVisible = initialButtonVisible
        self.angleDegMax = angleDegMax
        self.positionMax = positionMax
        self.wireframeInitial = wireframeInitial
        self.onUpdate = onUpdate
        self.onWireframe = onWireframe
        self.onButtonVisible = onButtonVisible
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _angleDeg = State(initialValue: initialAngleDeg)
        _position = State(initialValue: initialPosition)
        _wireframe = State(initialValue: wireframeInitial)
        _buttonsVisible = State(initialValue: initialButtonVisible)
    }

    var body: some View {
        FoldDialogScrim(dismissOnScrimTap: true, onDismiss: onCancel) {
            FoldDialogCard(title: FoldStrings.settingsTitle,
                           icon: "ic_settings_dark_24dp",
                           contentPadding: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 16),
                           buttons: [
                               FoldDialogButton(text: "cancel", action: onCancel),
                               FoldDialogButton(text: "ok", primary: true) {
                                   onConfirm(angleDeg, position, wireframe)
                               },
                           ]) {
                VStack(alignment: .leading, spacing: 0) {
                    FoldSeekBarRow(icon: "ic_swap_horiz_dark_24dp",
                                   label: FoldStrings.positionLabel,
                                   maxValue: Double(max(1, positionMax)),
                                   value: Double(position)) { newValue in
                        position = Int(newValue)
                        onUpdate(angleDeg, position)
                    }
                    FoldSeekBarRow(icon: "ic_cached_dark_24dp",
                                   label: FoldStrings.angleLabel,
                                   maxValue: Double(max(1, angleDegMax)),
                                   value: Double(angleDeg)) { newValue in
                        angleDeg = Int(newValue)
                        onUpdate(angleDeg, position)
                    }
                    FoldCheckRow(label: FoldStrings.wireframeText,
                                 isOn: wireframe,
                                 leadingPadding: 20) { newValue in
                        wireframe = newValue
                        onWireframe(newValue)
                    }
                    FoldCheckRow(label: FoldStrings.showButtonsText,
                                 isOn: buttonsVisible,
                                 leadingPadding: 20) { newValue in
                        buttonsVisible = newValue
                        onButtonVisible(newValue)
                    }
                }
            }
            .frame(maxWidth: 360)
        }
    }
}
