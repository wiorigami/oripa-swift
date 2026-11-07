// Editor-local chrome helpers that reproduce the web port's Material look exactly.
//
// Icon colours follow the web port's `M.icon` contract: monochrome Android drawables are
// masked with `currentColor` (theme roles `rgba(0,0,0,.54)` / `.38`), while the ORIPA tool
// and line-type drawables keep their own full-colour fills. `MaterialIcon` renders a tinted
// image from the drawable's luminance mask, so passing the Material role colour reproduces
// the reference colour on any surface; multi-colour drawables must be rendered untinted.
// Opaque assets that are baked with the wrong colour (e.g. the white
// `ic_arrow_back_dark_24dp` PNG) get an explicit tint.
//
// The CSS elevation shadows are also reproduced here (the DesignSystem token is a single
// softer shadow): elevation 4 = `0 2px 5px rgba(0,0,0,.22), 0 1px 3px rgba(0,0,0,.14)`.
// Shadows are attached to the bar *background* shapes so they cannot fall behind the
// translucent glyphs (which would darken them compared with the reference).
// Shared by PaintChrome, CheckScreen and the editor dialogs — all private to this scope.
import SwiftUI

// MARK: - Icon roles

/// Material icon colour role used by the editor chrome (`theme.css` `--m-icon-*`).
enum EditorIconRole {
    /// `--m-icon-active`: `color: rgba(0,0,0,.54)` — Material monochrome icons.
    case active
    /// `--m-icon-inactive`: `rgba(0,0,0,.38)`.
    case inactive
    /// Disabled icon button: `inactive` with the button's `.7` opacity (≈ 27 %).
    case disabled
    /// `--m-text-primary`; used by glyphs that inherit the row's text colour.
    case textPrimary
    /// `--m-icon-light`: white icons on the accent FAB / dark chips.
    case light
    /// Full-colour ORIPA tool/line-type drawables (grey plate + red/blue strokes):
    /// the web port renders these with their own SVG fills, not `currentColor`.
    case original
    /// Explicit colour for assets that are baked with another colour (e.g. the white
    /// `ic_arrow_back_dark_24dp` PNG).
    case tint(Color)
}

/// Material icon with the reference's alpha semantics (see the file header).
struct EditorIcon: View {
    var name: String
    var size: CGFloat = 24
    var role: EditorIconRole = .active

    var body: some View {
        switch role {
        case .active:
            MaterialIcon(name, size: size, tint: OrTheme.iconActive)
        case .inactive:
            MaterialIcon(name, size: size, tint: OrTheme.iconInactive)
        case .disabled:
            // `.m-icon-button.m-disabled { color: inactive; opacity: .7 }` → 0.38 × 0.7.
            MaterialIcon(name, size: size, tint: OrTheme.iconInactive).opacity(0.7)
        case .textPrimary:
            MaterialIcon(name, size: size, tint: OrTheme.textPrimary)
        case .light:
            MaterialIcon(name, size: size, tint: .white)
        case .original:
            // The raster carries the original drawable colours (help/tool illustrations).
            MaterialIcon(name, size: size)
        case .tint(let color):
            MaterialIcon(name, size: size, tint: color)
        }
    }
}

// MARK: - Icon button

/// `?android:borderlessButtonStyle` 48 × 48 icon button with the reference icon colours
/// and the Material `opacity: .7` disabled state (design-system `OrIconButton` is kept for
/// the rest of the app, which uses different tint roles).
struct EditorIconButton: View {
    var icon: String
    var title: String = ""
    var size: CGFloat = OrTheme.iconButtonSize
    var iconSize: CGFloat = 24
    var role: EditorIconRole = .active
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            EditorIcon(name: icon, size: iconSize, role: isEnabled ? role : .disabled)
                .frame(width: size, height: size)
        }
        .buttonStyle(OrPressableButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
        .help(title)
    }
}

// MARK: - Elevation

extension View {
    /// `m-elevation-4`: 0 2px 5px rgba(0,0,0,.22), 0 1px 3px rgba(0,0,0,.14).
    func editorElevation4() -> some View {
        self
            .shadow(color: .black.opacity(0.205), radius: 2.5, x: 0, y: 2)
            .shadow(color: .black.opacity(0.13), radius: 1.5, x: 0, y: 1)
    }

    /// `m-elevation-8`: 0 5px 12px rgba(0,0,0,.24), 0 2px 5px rgba(0,0,0,.16).
    func editorElevation8() -> some View {
        self
            .shadow(color: .black.opacity(0.24), radius: 6, x: 0, y: 5)
            .shadow(color: .black.opacity(0.16), radius: 2.5, x: 0, y: 2)
    }
}

// MARK: - Press feedback

/// Material list-row press tint (`.ui-choice-row:active { rgba(0,0,0,.06) }`).
struct EditorRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.06) : Color.clear)
    }
}

// MARK: - Dialog building blocks

/// AlertDialog heading (`ui-dialog-heading`): 24 dp icon, 16 dp gap, 20/28 title,
/// 8/10 vertical padding. Placed at the top of a dialog's content, the card's 16 dp
/// content top padding puts the 28 dp title line exactly 16 dp below the card edge.
struct EditorDialogHeading: View {
    var icon: String
    var title: String

    var body: some View {
        HStack(spacing: 16) {
            EditorIcon(name: icon, size: 24)
                .frame(width: 24, height: 24)
            Text(title)
                .font(OrTheme.dialogTitle())
                .foregroundColor(OrTheme.textPrimary)
                // The reference single-line 20/28 Roboto heading must not wrap in the
                // 284 dp export card; SF Pro is slightly wider, so scale down minimally.
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minHeight: 28, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 10)
    }
}

/// `ui-choice-row`: 48 dp row, 16 dp text, Material radio at the trailing edge.
/// The parent content already has the reference's 24 dp side padding (the CSS list uses
/// negative margins to cancel the row padding), so rows carry no extra inset.
struct EditorDialogChoiceRow: View {
    var label: String
    var isChecked: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(OrTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                OrRadioMark(isChecked: isChecked)
            }
            .frame(minHeight: OrTheme.listItemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(EditorRowButtonStyle())
    }
}

/// A Material dialog text button with an explicit colour (used by the Export dialog whose
/// positive button stays disabled until a file type is picked).
struct EditorDialogTextButton: View {
    var text: String
    var color: Color
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text.uppercased())
                .font(OrTheme.button())
                .kerning(1.12) // CSS letter-spacing: .08em at 14 sp
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(OrPressableButtonStyle(shape: AnyShape(RoundedRectangle(cornerRadius: 2)),
                                            pressedTint: OrTheme.ripple))
        .disabled(!isEnabled)
    }
}
