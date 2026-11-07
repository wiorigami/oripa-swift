// Fold-local Material chrome (fold screen + fold dialogs).
//
// The fold UI is heavily custom (transparent floating toolbar over a full-screen canvas,
// cut-line mini buttons, HSV colour wheel, Android `NumberPicker` wheel), so it builds its
// own SwiftUI chrome from the exact tokens of `src/css/theme.css` + `components.css` +
// `fold.css` instead of the generic ORIPA DesignSystem widgets. `MaterialIcon` (owned by
// ui-shell) is reused for every icon.
import SwiftUI
import ORIPACore

// MARK: - Theme tokens (theme.css / colors.xml)

enum FoldTheme {
    /// `--m-primary`: colorPrimary = grey_100 #f5f5f5.
    static let primary = SwiftUI.Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255)
    /// `--m-primary-dark`: grey_400 #bdbdbd.
    static let primaryDark = SwiftUI.Color(red: 189 / 255, green: 189 / 255, blue: 189 / 255)
    /// `--m-background`: grey_50 #fafafa.
    static let background = SwiftUI.Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255)
    /// `--m-surface`: white card background.
    static let surface = SwiftUI.Color.white
    /// `--m-accent`: colorAccent = pink_500 #e91e63.
    static let accent = SwiftUI.Color(red: 233 / 255, green: 30 / 255, blue: 99 / 255)
    /// `--m-text-primary`: rgba(0,0,0,.87).
    static let textPrimary = SwiftUI.Color(white: 0, opacity: 0.87)
    /// `--m-text-secondary`: rgba(0,0,0,.54).
    static let textSecondary = SwiftUI.Color(white: 0, opacity: 0.54)
    /// `--m-text-disabled`: rgba(0,0,0,.38).
    static let textDisabled = SwiftUI.Color(white: 0, opacity: 0.38)
    /// `--m-divider`: rgba(0,0,0,.12).
    static let divider = SwiftUI.Color(white: 0, opacity: 0.12)
    /// `--m-icon-active`: rgba(0,0,0,.54).
    static let iconActive = SwiftUI.Color(white: 0, opacity: 0.54)
    /// `--m-icon-inactive`: rgba(0,0,0,.38).
    static let iconInactive = SwiftUI.Color(white: 0, opacity: 0.38)
    /// `--m-scrim`: rgba(0,0,0,.32).
    static let scrim = SwiftUI.Color(white: 0, opacity: 0.32)
    /// Seekbar inactive track: rgba(0,0,0,.26).
    static let track = SwiftUI.Color(white: 0, opacity: 0.26)
    /// Drawer/snackbar surface (#323232 in components.css).
    static let snackbarBackground = SwiftUI.Color(red: 50 / 255, green: 50 / 255, blue: 50 / 255)

    /// `--m-toolbar-height` / Android `?attr/actionBarSize` (56 dp).
    static let toolbarHeight: CGFloat = 56
    /// Android list item height (48 dp).
    static let listItemHeight: CGFloat = 48
    /// Dialog max width (`m-dialog` max-width: min(560px, 100%)).
    static let dialogMaxWidth: CGFloat = 560
}

// MARK: - Icon button

/// `m-icon-button`: 48x48 transparent circular ripple target with a 24dp icon.
struct FoldIconButton: View {
    let icon: String
    let title: String
    var enabled: Bool = true
    var size: CGFloat = 24
    var tint: SwiftUI.Color = FoldTheme.iconActive
    var disabledTint: SwiftUI.Color = FoldTheme.iconInactive
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MaterialIcon(icon, size: size, tint: enabled ? tint : disabledTint)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - FAB

/// `m-fab`: 56dp accent circle, white icon, material elevation shadow.
struct FoldFAB: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MaterialIcon(icon, size: 24, tint: .white)
                .frame(width: 56, height: 56)
                .background(FoldTheme.accent, in: Circle())
                .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 3)
                .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Dialog chrome

/// One AlertDialog text button (`m-text-button`; primary = accent, uppercase, letter-spaced).
struct FoldDialogButton: Identifiable {
    let id = UUID()
    let text: String
    var primary: Bool = false
    var enabled: Bool = true
    let action: () -> Void
}

/// `m-dialog-scrim`: dimmed background, content centred, scrim taps dismiss when allowed.
struct FoldDialogScrim<Content: View>: View {
    var dismissOnScrimTap: Bool = true
    var onDismiss: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            FoldTheme.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    guard dismissOnScrimTap else { return }
                    onDismiss?()
                }
            content()
                .padding(24)
        }
        .transition(.opacity)
    }
}

/// `m-dialog` card: surface, 2dp corners, title row (with optional leading icon,
/// AlertDialog `setIcon`), content and right-aligned text-button actions.
struct FoldDialogCard<Content: View>: View {
    var title: String?
    var icon: String?
    var contentPadding = EdgeInsets(top: 16, leading: 24, bottom: 8, trailing: 24)
    let buttons: [FoldDialogButton]
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(spacing: 16) {
                    if let icon {
                        MaterialIcon(icon, size: 24, tint: FoldTheme.iconActive)
                    }
                    Text(title)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(FoldTheme.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
            }
            content()
                .padding(contentPadding)
            if !buttons.isEmpty {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    ForEach(buttons) { button in
                        FoldTextButton(text: button.text,
                                       primary: button.primary,
                                       enabled: button.enabled,
                                       action: button.action)
                    }
                }
                .padding(8)
                .frame(minHeight: 52)
            }
        }
        .frame(maxWidth: FoldTheme.dialogMaxWidth)
        .background(FoldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .shadow(color: .black.opacity(0.26), radius: 16, x: 0, y: 8)
    }
}

/// `m-text-button` (uppercase, letterSpacing .08em, accent when primary).
struct FoldTextButton: View {
    let text: String
    var primary: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text.uppercased())
                .font(.system(size: 14, weight: .medium))
                .kerning(1.12)
                .foregroundStyle(enabled ? (primary ? FoldTheme.accent : FoldTheme.textSecondary)
                                         : FoldTheme.textDisabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Checkbox row

/// `m-checkbox`: 18dp box, 2dp border; checked = accent fill + white check.
struct FoldCheckbox: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isOn ? FoldTheme.accent : SwiftUI.Color.clear)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(isOn ? FoldTheme.accent : FoldTheme.iconActive, lineWidth: 2)
            if isOn {
                MaterialIcon("ic_done_dark_24dp", size: 14, tint: .white)
            }
        }
        .frame(width: 18, height: 18)
    }
}

/// Android `CheckBox` row: box + label; the whole 48dp row toggles.
struct FoldCheckRow: View {
    let label: String
    var isOn: Bool
    var leadingPadding: CGFloat = 20
    let onChange: (Bool) -> Void

    var body: some View {
        Button {
            onChange(!isOn)
        } label: {
            HStack(spacing: 12) {
                FoldCheckbox(isOn: isOn)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(FoldTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, 8)
            .frame(minHeight: FoldTheme.listItemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Seek bar

/// Android SeekBar (Material): 4dp track, accent progress, 14dp thumb.
/// `value` is 0...`maxValue`; the drag reports rounded integer values like the JS port.
struct FoldSeekBar: View {
    let maxValue: Double
    let value: Double
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let fraction = maxValue > 0 ? min(1, max(0, value / maxValue)) : 0
            let thumbX = width * fraction
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FoldTheme.track)
                    .frame(height: 4)
                Capsule()
                    .fill(FoldTheme.accent)
                    .frame(width: thumbX, height: 4)
                Circle()
                    .fill(FoldTheme.accent)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.35), radius: 1.5, x: 0, y: 1)
                    .offset(x: thumbX - 7)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let ratio = min(1, max(0, gesture.location.x / width))
                        let newValue = (ratio * maxValue).rounded()
                        onChange(newValue)
                    }
            )
        }
        .frame(height: 32)
    }
}

/// Cut-line settings seekbar row: 56dp icon, label above the seekbar (`fold.css`).
struct FoldSeekBarRow: View {
    let icon: String
    let label: String
    let maxValue: Double
    let value: Double
    let onChange: (Double) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MaterialIcon(icon, size: 24, tint: FoldTheme.iconActive)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(FoldTheme.textPrimary)
                FoldSeekBar(maxValue: maxValue, value: value, onChange: onChange)
            }
        }
        .frame(minHeight: 56)
        .padding(.trailing, 8)
    }
}

// MARK: - List rows

/// `fold-multichoice-row`: label + trailing checkbox (Android multi-choice list item).
struct FoldMultiChoiceRow: View {
    let label: String
    var isOn: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(FoldTheme.textPrimary)
                Spacer(minLength: 0)
                FoldCheckbox(isOn: isOn)
            }
            .padding(.horizontal, 24)
            .frame(minHeight: FoldTheme.listItemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// `fold-choice-row`: single-choice export list row with a radio dot.
struct FoldChoiceRow: View {
    let label: String
    var selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(FoldTheme.textPrimary)
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .strokeBorder(selected ? FoldTheme.accent : FoldTheme.textSecondary, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if selected {
                        Circle()
                            .fill(FoldTheme.accent)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, 24)
            .frame(minHeight: FoldTheme.listItemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ripple-free pressed style

/// Simple press highlight (`:active { background: rgba(0,0,0,.06) }`).
struct FoldPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(white: 0, opacity: 0.06) : SwiftUI.Color.clear)
    }
}
