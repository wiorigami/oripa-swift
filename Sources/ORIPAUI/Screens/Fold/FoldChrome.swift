// Fold screen chrome — port of `res/layout/fragment_fold_cp.xml` + `menu/fold_cp_action_bar.xml`
// and the chrome construction in `oripa-port/src/js/ui/fragments/fold.js`:
//
//   * transparent floating toolbar (`background_gradient_transparent`) with back arrow,
//     the view-mode spinner ["X-Ray / Wireframe", "Overlap [BETA]", "Cut Line"] and the
//     settings gear (`fold_action_settings_title`);
//   * Cut Line move/rotate mini button column (`cross_button_container`,
//     `background_primary_rounded`): the active one reflects
//     `FoldCpFragment.crossOneFingerMove` (move = swap_horiz enabled + cached disabled,
//     or the reverse);
//   * export FAB (`ic_file_download_light_24dp`) at 16dp from the bottom-right.
import SwiftUI
import ORIPACore

// MARK: - Toolbar

/// Transparent floating toolbar: back arrow + mode spinner + settings gear.
@MainActor
struct FoldToolbar: View {
    @ObservedObject var model: FoldViewModel
    /// Safe-area top inset (status bar / notch); the toolbar sits below it.
    var topInset: CGFloat
    /// Measured width of the spinner control; the popup menu is anchored to its trailing
    /// edge (`M.menu`: left = anchor.right - 4).
    @Binding var spinnerWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // APK `fragment_fold_cp.xml`: Toolbar navigation icon is a 56 dp-wide button
            // flush at the left screen edge (24 dp arrow glyph centred).
            FoldIconButton(icon: "ic_arrow_back_dark_24dp", title: "Navigate up") {
                model.back()
            }
            .frame(width: 56)
            Button {
                model.showsModeMenu.toggle()
            } label: {
                HStack(spacing: 0) {
                    Text(FoldStrings.spinnerLabels[model.modeIndex])
                        .font(.system(size: 16))
                        .foregroundStyle(FoldTheme.textPrimary)
                    // AppCompat Spinner: label ink starts at 80 dp (56 nav + 16 content
                    // inset + 8 spinner padding); the dropdown caret sits at the right edge
                    // of the ~178 dp spinner control (28 dp after the label ink).
                    Spacer(minLength: 28)
                    MaterialIcon("ic_arrow_drop_down_black_24dp", size: 24,
                                 tint: FoldTheme.textPrimary)
                }
                .padding(.leading, 24)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
                .background(
                    GeometryReader { geometry in
                        SwiftUI.Color.clear
                            .preference(key: FoldSpinnerWidthKey.self, value: geometry.size.width)
                    }
                )
            }
            .buttonStyle(.plain)
            .onPreferenceChange(FoldSpinnerWidthKey.self) { width in
                spinnerWidth = width
            }
            .accessibilityLabel(Text("View mode"))
            Spacer(minLength: 0)
            // `fold_cp_action_bar.xml`: 48 dp settings button flush with the right edge.
            FoldIconButton(icon: "ic_settings_dark_24dp",
                           title: FoldStrings.settingsTitle) {
                model.openSettings()
            }
            .frame(width: 48)
        }
        .frame(height: FoldTheme.toolbarHeight)
        .padding(.top, topInset)
        .background(
            // `background_gradient_transparent`: opaque grey_100 at the top fading out over
            // the 56 dp toolbar; no elevation (the fold fragment clears it).
            LinearGradient(colors: [FoldTheme.primary, FoldTheme.primary.opacity(0)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
    }
}

/// Width of the toolbar spinner (the popup menu anchors to its trailing edge).
private struct FoldSpinnerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Mode spinner popup menu

/// The AppCompat Spinner popup (`M.menu` anchored to the toolbar spinner): white menu,
/// 8dp vertical padding, 48dp rows, check mark on the current item. The transparent
/// backdrop closes it. `M.menu` positions the popup with `left = anchor.right - 4` and
/// `top = anchor.bottom + 2` (clamping only when it would leave the viewport — the fold
/// spinner is narrow enough that it never does). Width = longest label (130 dp) + 92 dp
/// item chrome (2 x 16 padding, 24 dp icon-slot margin, 16 + 20 dp check mark).
@MainActor
struct FoldModeMenu: View {
    @ObservedObject var model: FoldViewModel
    /// Safe-area top inset of the screen (the menu hangs under the floating toolbar).
    var topInset: CGFloat
    /// Left edge of the popup (`M.menu`: spinner.right - 4).
    var leading: CGFloat

    static let menuWidth: CGFloat = 144

    var body: some View {
        ZStack(alignment: .topLeading) {
            SwiftUI.Color.clear
                .contentShape(Rectangle())
                .onTapGesture { model.showsModeMenu = false }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(FoldStrings.spinnerLabels.enumerated()), id: \.offset) { index, label in
                    Button {
                        model.selectMode(index)
                    } label: {
                        // AppCompat Spinner dropdown: 48 dp rows, 16 sp regular #212121,
                        // 8 dp left inset, NO radio/check marks (the spinner itself shows
                        // the selected value).
                        Text(label)
                            .font(.system(size: 16))
                            .foregroundStyle(FoldTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .padding(.leading, 8)
                            .frame(width: Self.menuWidth, alignment: .leading)
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FoldPressableStyle())
                }
            }
            .frame(width: Self.menuWidth)
            .background(FoldTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .shadow(color: .black.opacity(0.26), radius: 12, x: 0, y: 6)
            .padding(.leading, leading)
            // APK screenshot 14: the dropdown opens OVER the toolbar, its first row at
            // contentTop + 4 dp (the menu covers the spinner label).
            .padding(.top, topInset + 4)
        }
    }
}

/// `background_primary_rounded` / `.fold-cross-buttons` — only the two top corners are
/// rounded (2 dp); the column is anchored to the bottom edge.
struct FoldTopRoundedRectangle: Shape {
    var radius: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Cut-line move / rotate mini buttons

/// `cross_button_container`: bottom-left column, `background_primary_rounded`.
@MainActor
struct FoldCrossButtons: View {
    @ObservedObject var model: FoldViewModel

    var body: some View {
        VStack(spacing: 0) {
            FoldIconButton(icon: model.crossOneFingerMove
                                ? "ic_swap_horiz_dark_24dp"
                                : "ic_swap_horiz_dark_disabled_24dp",
                           title: FoldStrings.moveCutLineDescription,
                           enabled: model.crossOneFingerMove,
                           tint: FoldTheme.iconActive,
                           disabledTint: FoldTheme.iconInactive) {
                model.setCrossOneFingerMove(true)
            }
            FoldIconButton(icon: model.crossOneFingerMove
                                ? "ic_cached_dark_disabled_24dp"
                                : "ic_cached_dark_24dp",
                           title: FoldStrings.rotateCutLineDescription,
                           enabled: !model.crossOneFingerMove,
                           tint: FoldTheme.iconActive,
                           disabledTint: FoldTheme.iconInactive) {
                model.setCrossOneFingerMove(false)
            }
        }
        .background(FoldTheme.primary)
        .clipShape(FoldTopRoundedRectangle(radius: 2))
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .contain)
    }
}
