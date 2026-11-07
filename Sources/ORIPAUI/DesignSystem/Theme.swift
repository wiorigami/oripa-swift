// ORIPA theme — Material light look ported from the web port's `src/css/theme.css`
// (which came from `rev/apktool/res/values/colors.xml` + AppCompat defaults).
//
// All colours are the exact Android palette values; all sizes are dp (== pt).
// The app is intentionally a light-theme app like the Android original: the palette
// below is static, so the Material chrome does not follow the system dark appearance.
import SwiftUI

// MARK: - Color helpers

public extension Color {
    /// `Color(hex: 0xF5F5F5)` — RGB hex without alpha.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// `#AARRGGBB` Android colour int (used by the fold renderer options).
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        self.init(hex: argb & 0x00FF_FFFF, opacity: a)
    }
}

// MARK: - Theme

/// The Material design tokens shared by every ORIPA screen.
///
/// Sources: `src/css/theme.css` (custom properties), `src/css/components.css`
/// (component dimensions) and the Android `colors.xml`.
public enum OrTheme {

    // MARK: Colours (theme.css `:root`)

    /// `--m-primary`: colorPrimary / grey_100.
    public static let primary = Color(hex: 0xF5F5F5)
    /// `--m-primary-dark`: colorPrimaryDark / grey_400 (status-bar strip).
    public static let primaryDark = Color(hex: 0xBDBDBD)
    /// `--m-primary-selected`: colorPrimarySelected / grey_600 (contextual action bar).
    public static let primarySelected = Color(hex: 0x757575)
    /// `--m-accent`: colorAccent / pink_500 (FAB, switches, dialog buttons, links).
    public static let accent = Color(hex: 0xE91E63)
    /// `--m-background`: window background / grey_50.
    public static let background = Color(hex: 0xFAFAFA)
    /// `--m-surface`: cards, list items, dialogs.
    public static let surface = Color.white
    /// `--m-text-primary`: `rgba(0,0,0,.87)`.
    public static let textPrimary = Color.black.opacity(0.87)
    /// `--m-text-secondary`: `rgba(0,0,0,.54)`.
    public static let textSecondary = Color.black.opacity(0.54)
    /// `--m-text-disabled`: `rgba(0,0,0,.38)`.
    public static let textDisabled = Color.black.opacity(0.38)
    /// `--m-divider`: `rgba(0,0,0,.12)`.
    public static let divider = Color.black.opacity(0.12)
    /// `--m-icon-active`: `rgba(0,0,0,.54)`.
    public static let iconActive = Color.black.opacity(0.54)
    /// `--m-icon-inactive`: `rgba(0,0,0,.38)`.
    public static let iconInactive = Color.black.opacity(0.38)
    /// `--m-icon-light`: white icons on `primarySelected` / accent.
    public static let iconLight = Color.white
    /// `--m-scrim`: dialog scrim `rgba(0,0,0,.32)`.
    public static let scrim = Color.black.opacity(0.32)
    /// `--m-ripple`: pressed-state tint for dark-on-light controls.
    public static let ripple = Color.black.opacity(0.12)
    /// Snackbar background (`components.css` `.m-snackbar`).
    public static let snackbarBackground = Color(hex: 0x323232)
    /// Item selection background: `colorAccentSelected` grey_300.
    public static let selectedItemBackground = Color(hex: 0xE0E0E0)
    /// Dialog/card white.
    public static let dialogBackground = Color.white
    /// Material switch off track (`rgba(0,0,0,.26)`).
    public static let switchOffTrack = Color.black.opacity(0.26)
    /// Material switch on track: accent at 50 %.
    public static let switchOnTrack = Color(hex: 0xE91E63, opacity: 0.5)
    /// Material switch thumb.
    public static let switchThumb = Color(hex: 0xFAFAFA)

    // MARK: Dimensions (dp/pt)

    /// `--m-toolbar-height`: 56 dp app bar.
    public static let toolbarHeight: CGFloat = 56
    /// `--m-list-item-height`: 48 dp list row.
    public static let listItemHeight: CGFloat = 48
    /// Contextual action-mode bar height (same as the app bar).
    public static let actionBarHeight: CGFloat = 56
    /// AppCompat icon button touch target: 48 × 48 dp.
    public static let iconButtonSize: CGFloat = 48
    /// Material FAB: 56 dp (mini: 40 dp).
    public static let fabSize: CGFloat = 56
    public static let fabMiniSize: CGFloat = 40
    /// RecyclerView grid item size used to compute the column count (180 dp).
    public static let gridImageDimension: CGFloat = 180
    /// Project grid gap: item layout margin 2 dp on each side.
    public static let projectGridGap: CGFloat = 4
    /// Projects list row height (72 dp).
    public static let projectListRowHeight: CGFloat = 72
    /// Project list thumbnail (32 dp).
    public static let projectListThumbSize: CGFloat = 32
    /// Project grid thumbnail check badge (56 dp with 8 dp padding).
    public static let projectCheckBadgeSize: CGFloat = 56
    /// Project item overflow button (40 dp wide).
    public static let projectOverflowSize: CGFloat = 40
    /// FAB margin from the safe area edge (16 dp).
    public static let fabMargin: CGFloat = 16
    /// Material dialog scrim padding (24 dp).
    public static let dialogPadding: CGFloat = 24
    /// Material dialog min width (280 dp).
    public static let dialogMinWidth: CGFloat = 280
    /// Material dialog max width (560 dp, about dialog).
    public static let dialogMaxWidth: CGFloat = 560
    /// Material snackbar min width (280 dp).
    public static let snackbarMinWidth: CGFloat = 280
    /// Toast/snackbar default duration (JS `M.snackbar`).
    public static let snackbarDuration: TimeInterval = 3.2
    /// Splash: `splash.js` SPLASH_DURATION_MS.
    public static let splashDuration: TimeInterval = 0.8
    /// Long-press duration that starts project selection mode (`projects.js` 500 ms).
    public static let longPressDuration: TimeInterval = 0.5
    /// Material seek bar height.
    public static let seekBarHeight: CGFloat = 32
    /// Material switch track/thumb.
    public static let switchWidth: CGFloat = 36
    public static let switchHeight: CGFloat = 20
    public static let switchThumbSize: CGFloat = 26
    /// Material dialog action row min height.
    public static let dialogActionsHeight: CGFloat = 52
    /// Slider/stepper accent.
    public static let stepperButtonSize: CGFloat = 40

    // MARK: Fonts
    //
    // Android uses Roboto; iOS/macOS have no Roboto bundle, so the system font is used
    // with the matching Material TextAppearance sizes/weights.
    public static func toolbarTitle() -> Font { .system(size: 20, weight: .medium) }
    public static func actionBarTitle() -> Font { .system(size: 20, weight: .medium) }
    public static func dialogTitle() -> Font { .system(size: 20, weight: .medium) }
    public static func body() -> Font { .system(size: 14) }
    public static func dialogText() -> Font { .system(size: 16) }
    public static func button() -> Font { .system(size: 14, weight: .medium) }
    public static func menuItem() -> Font { .system(size: 16) }
    public static func projectGridTitle() -> Font { .system(size: 16) }
    public static func projectGridDate() -> Font { .system(size: 12) }
    public static func projectListTitle() -> Font { .system(size: 16) }
    public static func projectListDate() -> Font { .system(size: 14) }
    public static func settingsTitle() -> Font { .system(size: 16) }
    public static func settingsSummary() -> Font { .system(size: 13) }
    public static func caption() -> Font { .system(size: 12) }
}

// MARK: - Elevation

/// Material elevation shadows (theme.css `.m-elevation-*`).
public extension View {
    /// 0…24 dp elevation from the CSS box-shadow definitions, reproduced with the two
    /// shadow layers of each `m-elevation-*` rule:
    ///   elevation 4  → `0 2px 5px rgba(0,0,0,.22), 0 1px 3px rgba(0,0,0,.14)`
    ///   elevation 8  → `0 5px 12px rgba(0,0,0,.24), 0 2px 5px rgba(0,0,0,.16)`
    ///   elevation 24 → `0 12px 28px rgba(0,0,0,.28), 0 6px 12px rgba(0,0,0,.18)`
    @ViewBuilder
    func orElevation(_ level: CGFloat) -> some View {
        switch level {
        case ..<2:
            self
        case ..<6:
            // CSS 0 2px 5px .22 + 0 1px 3px .14. SwiftUI's shadow radius spreads about
            // twice as far as a CSS blur radius, so the CSS values are halved.
            self
                .shadow(color: .black.opacity(0.22), radius: 2.5, x: 0, y: 2)
                .shadow(color: .black.opacity(0.14), radius: 1.5, x: 0, y: 1)
        case ..<12:
            self
                .shadow(color: .black.opacity(0.24), radius: 6, x: 0, y: 5)
                .shadow(color: .black.opacity(0.16), radius: 2.5, x: 0, y: 2)
        default:
            self
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 12)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 6)
        }
    }
}

// MARK: - Shared background

/// The Material window background used behind every screen.
public struct OrScreenBackground: View {
    public init() {}
    public var body: some View {
        OrTheme.background.ignoresSafeArea()
    }
}

// MARK: - Typography modifiers

public extension View {
    func orToolbarTitleStyle() -> some View {
        self.font(OrTheme.toolbarTitle()).foregroundColor(OrTheme.textPrimary)
    }

    func orDialogTitleStyle() -> some View {
        self.font(OrTheme.dialogTitle()).foregroundColor(OrTheme.textPrimary)
    }

    /// Material `line-height` for a text run.
    ///
    /// The web port sets an explicit CSS `line-height` on nearly every text style
    /// (`components.css`, `projects.css`, `settings.css`); SwiftUI's default SF line
    /// height is ~19.3 % larger than the font size, which made every multi-line block
    /// and every row that is sized by its content a little shorter than the reference.
    /// `orLineHeight` adds the matching leading between wrapped lines and gives a single
    /// line an explicit box height, so rows hug the Android metrics.
    ///
    /// - Parameters:
    ///   - lineHeight: CSS `line-height` in dp.
    ///   - fontSize: the font's size in dp (used for SwiftUI's default line height).
    func orLineHeight(_ lineHeight: CGFloat, fontSize: CGFloat) -> some View {
        let defaultLineHeight = fontSize * 1.1934
        return self
            .lineSpacing(max(0, lineHeight - defaultLineHeight))
            .frame(minHeight: lineHeight)
    }
}
