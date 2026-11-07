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

// MARK: - Preference category

/// Android `PreferenceCategory` heading (accent uppercase).
public struct OrPreferenceCategory: View {
    public var title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .medium))
                .kerning(0.84)
                .foregroundColor(OrTheme.accent)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .frame(minHeight: 48, alignment: .bottom)
        .background(OrTheme.background)
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
    public var onChange: ((Bool) -> Void)?

    public init(title: String,
                summary: String? = nil,
                iconOn: String? = nil,
                iconOff: String? = nil,
                isOn: Binding<Bool>,
                isEnabled: Bool = true,
                onChange: ((Bool) -> Void)? = nil) {
        self.title = title
        self.summary = summary
        self.iconOn = iconOn
        self.iconOff = iconOff
        self._isOn = isOn
        self.isEnabled = isEnabled
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
            HStack(spacing: 16) {
                if let icon = currentIcon {
                    MaterialIcon(icon, size: 24, tint: OrTheme.iconActive)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OrTheme.settingsTitle())
                        .foregroundColor(OrTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let summary {
                        Text(summary)
                            .font(OrTheme.settingsSummary())
                            .foregroundColor(OrTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                OrMaterialSwitch(isOn: isOn, enabled: isEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(OrSettingsRowButtonStyle(enabled: isEnabled))
        .disabled(!isEnabled)
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }
}

/// `ListPreference` / `NumberPickerPreference` style row with a value summary and chevron.
public struct OrListPreferenceRow: View {
    public var title: String
    public var summary: String
    public var showsChevron: Bool
    public var isEnabled: Bool
    public var action: () -> Void

    public init(title: String,
                summary: String,
                showsChevron: Bool = true,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.title = title
        self.summary = summary
        self.showsChevron = showsChevron
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: { if isEnabled { action() } }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OrTheme.settingsTitle())
                        .foregroundColor(OrTheme.textPrimary)
                    Text(summary)
                        .font(OrTheme.settingsSummary())
                        .foregroundColor(OrTheme.textSecondary)
                }
                Spacer(minLength: 8)
                if showsChevron {
                    MaterialIcon("ic_chevron_right_dark_24dp", size: 24, tint: OrTheme.iconActive)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(OrSettingsRowButtonStyle(enabled: isEnabled))
        .disabled(!isEnabled)
    }
}

private struct OrSettingsRowButtonStyle: ButtonStyle {
    var enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.04) : OrTheme.surface)
            .opacity(enabled ? 1 : 0.45)
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

    public init(model: OrNumberPickerModel, onChanged: ((Int) -> Void)? = nil) {
        self.model = model
        self.onChanged = onChanged
    }

    public var body: some View {
        HStack(spacing: 8) {
            stepperButton("\u{2212}") { change(model.value - 1) }
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
        VStack(spacing: 8) {
            if let label {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(OrTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                if let halfLabel {
                    Button {
                        model.halve()
                    } label: {
                        Text(halfLabel)
                            .font(OrTheme.button())
                            .foregroundColor(OrTheme.accent)
                            .frame(minWidth: 64)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 4) {
                    OrNumberPicker(model: model)
                    Text(String(model.value))
                        .font(.system(size: 18))
                        .foregroundColor(OrTheme.textPrimary)
                        .frame(minHeight: 24)
                }
                .frame(minWidth: 120)
                if let twiceLabel {
                    Button {
                        model.double()
                    } label: {
                        Text(twiceLabel)
                            .font(OrTheme.button())
                            .foregroundColor(OrTheme.accent)
                            .frame(minWidth: 64)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }
}
