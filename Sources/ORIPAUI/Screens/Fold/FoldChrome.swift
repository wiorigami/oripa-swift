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

    var body: some View {
        HStack(spacing: 0) {
            FoldIconButton(icon: "ic_arrow_back_dark_24dp", title: "Navigate up") {
                model.back()
            }
            Button {
                model.showsModeMenu.toggle()
            } label: {
                HStack(spacing: 2) {
                    Text(FoldStrings.spinnerLabels[model.modeIndex])
                        .font(.system(size: 16))
                        .foregroundStyle(FoldTheme.textPrimary)
                    MaterialIcon("ic_arrow_drop_down_black_24dp", size: 24, tint: FoldTheme.iconActive)
                }
                .padding(.horizontal, 4)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("View mode"))
            Spacer(minLength: 0)
            FoldIconButton(icon: "ic_settings_dark_24dp", title: FoldStrings.settingsTitle) {
                model.openSettings()
            }
        }
        .padding(.horizontal, 4)
        .frame(height: FoldTheme.toolbarHeight)
        .padding(.top, topInset)
        .background(
            LinearGradient(colors: [FoldTheme.primary.opacity(0.94), FoldTheme.primary.opacity(0)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
    }
}

// MARK: - Mode spinner popup menu

/// The AppCompat Spinner popup (`M.menu` anchored to the toolbar spinner): white menu,
/// 48dp rows, check mark on the current item.
@MainActor
struct FoldModeMenu: View {
    @ObservedObject var model: FoldViewModel

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
                        HStack(spacing: 16) {
                            Text(label)
                                .font(.system(size: 16))
                                .foregroundStyle(FoldTheme.textPrimary)
                            Spacer(minLength: 0)
                            if index == model.modeIndex {
                                MaterialIcon("ic_done_dark_24dp", size: 20, tint: FoldTheme.textPrimary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(FoldPressableStyle())
                }
            }
            .frame(minWidth: 180)
            .background(FoldTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .shadow(color: .black.opacity(0.26), radius: 12, x: 0, y: 6)
        }
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
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .contain)
    }
}
