// Material small controls: seek bar, preference rows, number stepper/picker and the
// preference category heading.
//
// Port of `M.seekBar`, `M.switchRow`, `M.numberStepper`, `M.listRow` and
// `M.checkbox` from `src/js/ui/components/material.js`, the settings preference rows of
// `src/js/ui/screens/settings.js` and the corresponding `src/css/{components,settings}.css`
// rules. All sizes are dp.
import SwiftUI

// MARK: - Seek bar

/// Material seek bar (`M.seekBar`): 4 dp track, accent active part, 14 dp thumb.
public struct OrSeekBar: View {
    @Binding public var value: Double
    public var minValue: Double
    public var maxValue: Double
    public var step: Double?
    /// Called continuously while dragging (`opts.onInput`).
    public var onInput: ((Double) -> Void)?
    /// Called once when the drag ends (`opts.onChange`).
    public var onChange: ((Double) -> Void)?

    @State private var isDragging = false

    public init(value: Binding<Double>,
                minValue: Double = 0,
                maxValue: Double = 100,
                step: Double? = nil,
                onInput: ((Double) -> Void)? = nil,
                onChange: ((Double) -> Void)? = nil) {
        self._value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.onInput = onInput
        self.onChange = onChange
    }

    private var fraction: CGFloat {
        guard maxValue > minValue else { return 0 }
        let clamped = Swift.min(Swift.max(value, minValue), maxValue)
        return CGFloat((clamped - minValue) / (maxValue - minValue))
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let thumbSize: CGFloat = 14
            let usable = Swift.max(0, width - thumbSize)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.26))
                    .frame(height: 4)
                Capsule()
                    .fill(OrTheme.accent)
                    .frame(width: usable * fraction + thumbSize / 2, height: 4)
                Circle()
                    .fill(OrTheme.accent)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
                    .offset(x: usable * fraction)
            }
            .frame(width: width, height: OrTheme.seekBarHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                        }
                        updateValue(for: gesture.location.x, usable: usable)
                        onInput?(value)
                    }
                    .onEnded { gesture in
                        updateValue(for: gesture.location.x, usable: usable)
                        isDragging = false
                        onChange?(value)
                    }
            )
        }
        .frame(height: OrTheme.seekBarHeight)
        .padding(.horizontal, 2)
    }

    private func updateValue(for x: CGFloat, usable: CGFloat) {
        guard usable > 0 else { return }
        let ratio = Swift.min(Swift.max((x - 7) / usable, 0), 1)
        var newValue = minValue + Double(ratio) * (maxValue - minValue)
        if let step, step > 0 {
            newValue = (newValue / step).rounded() * step
        }
        value = Swift.min(Swift.max(newValue, minValue), maxValue)
    }
}

// MARK: - Preference metrics (measured from the APK)

/// Android text-metric envelopes and row geometry of the preference list, measured from the
/// reference APK (`ORIPA 0.2.3.3`, 1080 × 2400 px, density 420 → 1 dp = 2.625 px).
///
/// `preference_compat_material.xml` gives the rows no explicit height: they are sized by
/// `paddingTop/Bottom` of the text column plus the text's own line boxes. In the APK those
/// boxes are larger than SF's default line height, so the constraints below reproduce the
/// rows measured in `04-test-menu.png` exactly:
///
///   * single-line preference (`Subhead` 16 sp, no summary):
///     16 + 22.857 + 16 = **54.857 dp** (measured 144 px = 54.86 dp);
///   * two-line preference (`Subhead` + `Body1` 14 sp summary):
///     16 + 22.857 + 19.429 + 16 = **74.286 dp** (measured 195 px = 74.29 dp);
///   * category header (`paddingTop` 16 + `Body2`-sized bold 14 sp):
///     **35.43 dp** (measured 91 px = 34.7 dp; the XML's `layout_marginBottom="16dp"` is
///     ignored by the framework preference ListView, which drops item margins).
public enum OrMaterialMetrics {
    /// `TextAppearance.AppCompat.Subhead` 16 sp line box (60 px @ 2.625).
    public static let subheadLineHeight: CGFloat = 22.857
    /// `TextAppearance.AppCompat.Body1` 14 sp line box (51 px @ 2.625).
    public static let body1LineHeight: CGFloat = 19.429
    /// `TextAppearance.AppCompat.Caption` 12 sp line box.
    public static let captionLineHeight: CGFloat = 17.143
    /// Preference text column `paddingTop` / `paddingBottom` (`@dimen/text_margin`).
    public static let preferencePadding: CGFloat = 16
    /// `android:id="@android:id/icon"`: 24 dp drawable, `scaleType="fitStart"`, drawn at
    /// x = 12 dp inside the 72 dp icon column (measured icon ink 53.7…77.7 px from the
    /// screen edge, i.e. 12 dp from the row's leading edge).
    public static let preferenceIconLeading: CGFloat = 12
    public static let preferenceIconSize: CGFloat = 24
    /// Title/summary column start when the row has an icon (72 dp from the row edge).
    public static let preferenceTextLeading: CGFloat = 72
    /// Title/summary column start for rows without an icon (the icon view is `GONE`, so the
    /// text column collapses onto the row padding).
    public static let preferenceNoIconLeading: CGFloat = 16
    /// `android:id="@android:id/widget_frame"` `paddingLeft`.
    public static let preferenceWidgetLeading: CGFloat = 16
    /// Trailing inset of the switch (APK: switch ink ends 17.5 dp from the screen edge).
    public static let preferenceTrailing: CGFloat = 16
    /// `listPreferredItemHeightSmall` — the minimum height of a preference row.
    public static let preferenceMinHeight: CGFloat = 48
}

// MARK: - Preference category

/// Android `PreferenceCategory` heading.
///
/// `preference_category_compat_material.xml` + `AppTheme.PreferenceListSeparatorTextView`:
/// `TextAppearance.Small` (14 sp), bold, `?attr/colorAccent`, `paddingTop` 16 dp,
/// `paddingLeft` 16 dp. `layout_marginBottom="16dp"` is *not* applied by the Android list
/// (measured: the following row starts flush against the header).
public struct OrPreferenceCategory: View {
    public var title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        HStack(spacing: 0) {
            // Android's list-separator text style keeps the label's original case.
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(OrTheme.accent)
                .orLineHeight(OrMaterialMetrics.body1LineHeight, fontSize: 14)
            Spacer(minLength: 0)
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.top, OrMaterialMetrics.preferencePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrTheme.background)
    }
}

// MARK: - Preference row chrome

/// Leading block of a preference row: the icon column (24 dp icon at x = 12 dp, text column
/// at x = 72 dp) or, when the preference has no icon, a plain 16 dp inset.
private struct OrPreferenceLeading: View {
    var icon: String?

    var body: some View {
        if let icon {
            HStack(spacing: 0) {
                Color.clear.frame(width: OrMaterialMetrics.preferenceIconLeading, height: 0)
                MaterialIcon(icon, size: OrMaterialMetrics.preferenceIconSize, tint: OrTheme.iconActive)
                Color.clear.frame(width: OrMaterialMetrics.preferenceTextLeading
                                   - OrMaterialMetrics.preferenceIconLeading
                                   - OrMaterialMetrics.preferenceIconSize,
                                   height: 0)
            }
        } else {
            Color.clear.frame(width: OrMaterialMetrics.preferenceNoIconLeading, height: 0)
        }
    }
}

/// Title (Subhead 16 sp) + optional summary (Body1 14 sp secondary) text column.
///
/// The line boxes are pinned to the heights measured in the APK (`OrMaterialMetrics`)
/// instead of relying on the platform font's own line height, so the preference rows come
/// out at exactly 54.857 dp (single line) / 74.286 dp (title + summary).
private struct OrPreferenceTextColumn: View {
    var title: String
    var summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(OrTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .frame(height: OrMaterialMetrics.subheadLineHeight)
            if let summary {
                Text(summary)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(OrTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: OrMaterialMetrics.body1LineHeight, alignment: .top)
            }
        }
        .padding(.top, OrMaterialMetrics.preferencePadding)
        .padding(.bottom, OrMaterialMetrics.preferencePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// `preference_compat_material.xml` root background: the list draws on the window
/// background (grey_50) — preferences are not white cards.
private struct OrSettingsRowButtonStyle: ButtonStyle {
    var enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.04) : OrTheme.background)
            .opacity(enabled ? 1 : 0.38)
    }
}

// MARK: - Switch row

/// `SwitchPreferenceCompatMaterial` row: icon (on/off variant swaps with the value),
/// title, optional summary and the Material switch. Tapping the row toggles the value.
public struct OrSwitchRow: View {
    public var title: String
    public var summary: String?
    public var iconOn: String?
    public var iconOff: String?
    @Binding public var isOn: Bool
    public var isEnabled: Bool
    /// 1 dp `#1f000000` divider under the row (the framework list's item divider).
    public var showsDivider: Bool
    public var onChange: ((Bool) -> Void)?

    public init(title: String,
                summary: String? = nil,
                iconOn: String? = nil,
                iconOff: String? = nil,
                isOn: Binding<Bool>,
                isEnabled: Bool = true,
                showsDivider: Bool = true,
                onChange: ((Bool) -> Void)? = nil) {
        self.title = title
        self.summary = summary
        self.iconOn = iconOn
        self.iconOff = iconOff
        self._isOn = isOn
        self.isEnabled = isEnabled
        self.showsDivider = showsDivider
        self.onChange = onChange
    }

    private var currentIcon: String? {
        if iconOn == nil && iconOff == nil { return nil }
        return isOn ? iconOn : iconOff
    }

    public var body: some View {
        Button {
            guard isEnabled else { return }
            isOn.toggle()
            onChange?(isOn)
        } label: {
            HStack(spacing: 0) {
                OrPreferenceLeading(icon: currentIcon)
                OrPreferenceTextColumn(title: title, summary: summary)
                Spacer(minLength: OrMaterialMetrics.preferenceWidgetLeading)
                OrMaterialSwitch(isOn: isOn, enabled: isEnabled)
            }
            .padding(.trailing, OrMaterialMetrics.preferenceTrailing)
            .frame(minHeight: OrMaterialMetrics.preferenceMinHeight)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(OrSettingsRowButtonStyle(enabled: isEnabled))
        .disabled(!isEnabled)
        .overlay(alignment: .bottom) {
            if showsDivider { OrDivider() }
        }
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }
}

/// `NumberPickerPreference` / `ListPreference` row: Subhead title + Body1 secondary summary
/// with the current value. The Android dialog preferences show no trailing affordance.
public struct OrListPreferenceRow: View {
    public var title: String
    public var summary: String
    public var showsChevron: Bool
    public var isEnabled: Bool
    public var showsDivider: Bool
    public var action: () -> Void

    public init(title: String,
                summary: String,
                showsChevron: Bool = false,
                isEnabled: Bool = true,
                showsDivider: Bool = true,
                action: @escaping () -> Void) {
        self.title = title
        self.summary = summary
        self.showsChevron = showsChevron
        self.isEnabled = isEnabled
        self.showsDivider = showsDivider
        self.action = action
    }

    public var body: some View {
        Button(action: { if isEnabled { action() } }) {
            HStack(spacing: 0) {
                OrPreferenceLeading(icon: nil)
                OrPreferenceTextColumn(title: title, summary: summary)
                if showsChevron {
                    MaterialIcon("ic_chevron_right_dark_24dp", size: 24, tint: OrTheme.iconActive)
                        .padding(.trailing, OrMaterialMetrics.preferenceTrailing)
                }
            }
            .frame(minHeight: OrMaterialMetrics.preferenceMinHeight)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(OrSettingsRowButtonStyle(enabled: isEnabled))
        .disabled(!isEnabled)
        .overlay(alignment: .bottom) {
            if showsDivider { OrDivider() }
        }
    }
}

// MARK: - Number picker

/// State object shared by the number stepper / number picker dialog.
@MainActor
public final class OrNumberPickerModel: ObservableObject {
    @Published public private(set) var value: Int
    public let minValue: Int
    public let maxValue: Int

    public init(value: Int, minValue: Int, maxValue: Int) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = Swift.min(Swift.max(value, minValue), maxValue)
    }

    public func setValue(_ newValue: Int) {
        value = Swift.min(Swift.max(newValue, minValue), maxValue)
    }

    public func increment(by delta: Int) {
        setValue(value + delta)
    }

    /// Settings "x1/2" button: `Math.max(min, floor(value / 2))`.
    public func halve() {
        setValue(Swift.max(minValue, Int((Double(value) / 2).rounded(.down))))
    }

    /// Settings "x2" button: `Math.min(max, ceil(value * 2))`.
    public func double() {
        setValue(Swift.min(maxValue, Int((Double(value) * 2).rounded(.up))))
    }
}

/// Material number stepper: −  [value]  + (`M.numberStepper`).
public struct OrNumberPicker: View {
    @ObservedObject public var model: OrNumberPickerModel
    public var onChanged: ((Int) -> Void)?

    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @Environment(\.oripaSnapshotMode) private var snapshotMode

    public init(model: OrNumberPickerModel, onChanged: ((Int) -> Void)? = nil) {
        self.model = model
        self.onChanged = onChanged
    }

    public var body: some View {
        HStack(spacing: 8) {
            stepperButton("\u{2212}") { change(model.value - 1) }
            Group {
                if snapshotMode {
                    Text(String(model.value))
                        .font(.system(size: 18))
                        .foregroundColor(OrTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: 84, height: 40)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(OrTheme.divider).frame(height: 2)
                        }
                } else {
                    TextField("", text: Binding(
                        get: { text },
                        set: { newText in
                            let digits = newText.filter { $0.isNumber }
                            text = String(digits.prefix(4))
                        }
                    ))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 18))
                    .foregroundColor(OrTheme.textPrimary)
                    .frame(width: 84, height: 40)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(OrTheme.divider).frame(height: 2)
                    }
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .focused($isFocused)
                    .onSubmit { commitText() }
                    .onChange(of: isFocused) { focused in
                        if !focused { commitText() }
                    }
                }
            }
            stepperButton("+") { change(model.value + 1) }
        }
        .onAppear { text = String(model.value) }
        .onChange(of: model.value) { newValue in
            if !isFocused { text = String(newValue) }
        }
    }

    private func stepperButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 22))
                .foregroundColor(OrTheme.accent)
                .frame(width: OrTheme.stepperButtonSize, height: OrTheme.stepperButtonSize)
                .contentShape(Circle())
        }
        .buttonStyle(OrPressableButtonStyle())
    }

    private func change(_ newValue: Int) {
        model.setValue(newValue)
        text = String(model.value)
        onChanged?(model.value)
    }

    private func commitText() {
        if let parsed = Int(text) {
            change(parsed)
        } else {
            text = String(model.value)
        }
    }
}

/// Content of the number-picker preference dialog (`dialog_number_picker.xml`):
/// optional label, the stepper, and the x1/2 / x2 buttons flanking it.
public struct OrNumberPickerDialogContent: View {
    @ObservedObject public var model: OrNumberPickerModel
    public var label: String?
    public var halfLabel: String?
    public var twiceLabel: String?

    public init(model: OrNumberPickerModel,
                label: String? = nil,
                halfLabel: String? = nil,
                twiceLabel: String? = nil) {
        self.model = model
        self.label = label
        self.halfLabel = halfLabel
        self.twiceLabel = twiceLabel
    }

    public var body: some View {
        // `dialog_number_picker.xml`: horizontal LinearLayout, `gravity="center"`,
        // `paddingLeft/Right="8dp"`, three `layout_weight="1"` children with
        // `layout_margin="8dp"` — half button | number picker | double button.
        VStack(spacing: 8) {
            if let label {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(OrTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 0) {
                if let halfLabel {
                    weightButton(halfLabel) { model.halve() }
                }
                OrNumberPicker(model: model)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                if let twiceLabel {
                    weightButton(twiceLabel) { model.double() }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
    }

    /// AppCompat dialog button (14 sp medium, uppercase, accent, weight 1).
    private func weightButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(OrTheme.button())
                .kerning(0.6)
                .foregroundColor(OrTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(8)
    }
}
