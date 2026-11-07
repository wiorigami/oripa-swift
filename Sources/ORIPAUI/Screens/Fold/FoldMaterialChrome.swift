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
    /// AlertDialog card width **measured from the APK** (`16-fold-settings-cross.png`:
    /// 71…1009 px @ 2.625 = 357.7 dp on a 411.4 dp screen). The platform sizes the dialog
    /// from the window metrics, not from the XML, so this value is kept as a density
    /// independent dp width and the iPad layout simply shows it centred.
    static let dialogWidth: CGFloat = 358
    /// `dialog_color_picker.xml` sets no width either; its AlertDialog measures the same
    /// 357.7 dp card on the reference device.
    static let colorDialogWidth: CGFloat = 358
    /// `abc_alert_dialog_title_material.xml`: `paddingTop=@dimen/abc_dialog_padding_top_material`
    /// (18 dp) with a 32 dp `@android:id/icon` and `layout_marginRight="8dip"`.
    static let dialogTitleTopPadding: CGFloat = 18
    static let dialogTitleIconSize: CGFloat = 32
    static let dialogTitleIconMargin: CGFloat = 8
    /// Dialog title line-height (`windowTitleStyle`, 20 sp / line-height 28).
    static let dialogTitleLineHeight: CGFloat = 28
    /// `m-dialog-content` line-height (inherited by the colour picker rows).
    static let dialogLineHeight: CGFloat = 24
    /// `TextAppearance.AppCompat.Subhead` 16 sp line box, measured in the APK (60 px).
    static let subheadLineHeight: CGFloat = 22.857
    /// `TextAppearance.AppCompat.Body1` 14 sp line box, measured in the APK (51 px).
    static let body1LineHeight: CGFloat = 19.429
    /// `abc_alert_dialog_button_bar_material.xml`: ButtonBarLayout padding 12/4 dp.
    static let dialogButtonBarHorizontalPadding: CGFloat = 12
    static let dialogButtonBarVerticalPadding: CGFloat = 4
    /// AppCompat alert button (`abc_action_button_min_width_material` 64 dp,
    /// measured bar height 62 dp = 4 + 54 + 4).
    static let dialogButtonMinWidth: CGFloat = 64
    static let dialogButtonHeight: CGFloat = 54
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
        // A custom style keeps the icon's own alpha (the enabled/disabled drawables carry
        // the Material opacity) instead of SwiftUI's automatic dimming of disabled
        // plain-style buttons.
        .buttonStyle(FoldPressableStyle())
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
                // `abc_alert_dialog_title_material.xml`: icon 32 dp + 8 dp, title
                // `?android:attr/windowTitleStyle` (20 sp, single line), 18 dp top padding.
                HStack(spacing: FoldTheme.dialogTitleIconMargin) {
                    if let icon {
                        MaterialIcon(icon, size: FoldTheme.dialogTitleIconSize, tint: FoldTheme.iconActive)
                    }
                    Text(title)
                        .font(.system(size: 20))
                        .foregroundStyle(FoldTheme.textPrimary)
                        .lineLimit(1)
                        .frame(height: FoldTheme.dialogTitleIconSize, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(.top, FoldTheme.dialogTitleTopPadding)
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
                .padding(.horizontal, FoldTheme.dialogButtonBarHorizontalPadding)
                .padding(.vertical, FoldTheme.dialogButtonBarVerticalPadding)
                .frame(minHeight: FoldTheme.dialogButtonHeight + 2 * FoldTheme.dialogButtonBarVerticalPadding)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .background(
            // The card surface owns the elevation shadow. Keeping it on a plain shape
            // (instead of the composited content) prevents ImageRenderer from casting the
            // inner artwork (colour wheel, swatches, text) onto the card itself.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(FoldTheme.surface)
                // `.m-elevation-24` profile (box-shadow: 0 12px 28px .28 + 0 6px
                // 12px .18), tuned against the reference dialog's shadow falloff.
                .shadow(color: .black.opacity(0.26), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 2)
        )
        .frame(maxWidth: FoldTheme.dialogMaxWidth)
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
                .padding(.horizontal, 8)
                .frame(minWidth: FoldTheme.dialogButtonMinWidth,
                       minHeight: FoldTheme.dialogButtonHeight)
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

/// Android `CheckBox` list row (`dialog_fold_cp_cross.xml` /
/// `dialog_fold_cp_overlap.xml`): `layout_height="48dp"`, `layout_marginLeft="20dp"`,
/// `paddingLeft="20dp"`, `textAppearance` Subhead.
///
/// Measured in `16-fold-settings-cross.png`: the 18 dp check box sits 26.7 dp from the
/// dialog's content edge and the 16 sp label starts at 73.1 dp — the same icon/label
/// column as the seek-bar rows (72 dp), so all fold-dialog rows share one text grid.
struct FoldCheckRow: View {
    let label: String
    var isOn: Bool
    /// Kept for the call sites: Android's 20 dp margin + 20 dp padding place the box at
    /// 26.7 dp; the value is folded into `boxLeading` below.
    var leadingPadding: CGFloat = 20
    let onChange: (Bool) -> Void

    /// 18 dp box + 28.4 dp gap → label at 73.1 dp (measured).
    private static let boxLeading: CGFloat = 26.66
    private static let labelGap: CGFloat = 28.48

    var body: some View {
        Button {
            onChange(!isOn)
        } label: {
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.boxLeading, height: 0)
                FoldCheckbox(isOn: isOn)
                Color.clear.frame(width: Self.labelGap, height: 0)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(FoldTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.trailing, 8)
            .frame(height: FoldTheme.listItemHeight)
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
                // AppCompat Material seek bar: `abc_seekbar_track_*_height_material` 2 dp,
                // 12 dp thumb (measured 31 px @ 2.625 in `16-fold-settings-cross.png`).
                Capsule()
                    .fill(FoldTheme.track)
                    .frame(height: 2)
                Capsule()
                    .fill(FoldTheme.accent)
                    .frame(width: thumbX, height: 2)
                Circle()
                    .fill(FoldTheme.accent)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.35), radius: 1.5, x: 0, y: 1)
                    .offset(x: thumbX - 6)
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

/// Cut-line settings seek-bar row (`dialog_fold_cp_cross.xml`):
///   * `ImageView` 56 × 56 dp with `paddingLeft="24dp"` / `paddingRight="8dp"` around the
///     24 dp drawable (so the glyph renders exactly 24 dp, not stretched to 56);
///   * the label column starts at 56 + 16 (`layout_marginLeft`) = **72 dp**, matching the
///     colour rows and the checkbox labels;
///   * the label is `TextAppearance.AppCompat.Subhead` (16 sp) and the seek bar's bottom is
///     constrained to the icon box's bottom, so label + bar = 56 dp.
///
/// Measured in `16-fold-settings-cross.png`: icon box 56 dp, track 2 dp centred at 39 dp
/// from the row top, 12 dp thumb; the two rows stack directly (56 + 56 dp).
struct FoldSeekBarRow: View {
    let icon: String
    let label: String
    let maxValue: Double
    let value: Double
    let onChange: (Double) -> Void

    private static let iconBox: CGFloat = 56

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            MaterialIcon(icon, size: 24, tint: FoldTheme.iconActive)
                .padding(.leading, 24)
                .padding(.trailing, 8)
                .frame(height: Self.iconBox)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(FoldTheme.textPrimary)
                    .lineLimit(1)
                    .frame(height: FoldTheme.subheadLineHeight, alignment: .leading)
                FoldSeekBar(maxValue: maxValue, value: value, onChange: onChange)
                    .frame(height: Self.iconBox - FoldTheme.subheadLineHeight)
            }
            .padding(.leading, 16)
        }
        .frame(height: Self.iconBox)
    }
}

// MARK: - List rows

/// `fold-multichoice-row`: label + trailing checkbox (Android multi-choice list item).
struct FoldMultiChoiceRow: View {
    let label: String
    var isOn: Bool
    let onToggle: () -> Void

    // The Android multi-choice item (`?attr/listChoiceIndicatorMultiple`) puts the check box
    // on the leading edge: measured box 26.7 dp / label 73.1 dp from the content edge in
    // `13-fold-settings-xray.png` — identical to the fold CheckBox rows.
    private static let boxLeading: CGFloat = 26.66
    private static let labelGap: CGFloat = 28.48

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.boxLeading, height: 0)
                FoldCheckbox(isOn: isOn)
                Color.clear.frame(width: Self.labelGap, height: 0)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(FoldTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.trailing, 8)
            .frame(height: FoldTheme.listItemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// AlertDialog single-choice row (`select_dialog_singlechoice_material.xml`, used by
/// `ExportExternalDialogFragment.setSingleChoiceItems`):
///   * `CheckedTextView` with `drawableStart="?android:attr/listChoiceIndicatorSingle"` — the
///     radio is on the **leading** edge, 24 dp wide;
///   * `paddingLeft="@dimen/abc_select_dialog_padding_start_material"` (20 dp),
///     `paddingRight="?attr/dialogPreferredPadding"` (24 dp), `drawablePadding="20dp"`;
///   * `?android:attr/textAppearanceMedium` (18 sp), `minHeight` 48 dp.
struct FoldChoiceRow: View {
    let label: String
    var selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
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
                .frame(width: 24, height: 24)
                Text(label)
                    .font(.system(size: 18))
                    .foregroundStyle(FoldTheme.textPrimary)
                    .padding(.leading, 20)      // android:drawablePadding
                Spacer(minLength: 0)
            }
            .padding(.leading, 20)
            .padding(.trailing, 24)
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
