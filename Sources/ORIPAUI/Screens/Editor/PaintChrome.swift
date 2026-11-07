// Floating paint-screen chrome: the two Material toolbars, the by-value column, the
// "Show Menus" affordance and the FAB mini menu.
//
// Port of `fragment_paint_cp.xml` / `paint_cp_action_bar.xml` / `paint_cp_top_bar.xml` /
// `paint_cp_fab_mini.xml` and the DOM-building code of
// `oripa-port/src/js/ui/fragments/paint.js`:
//   - main toolbar: done/close, toggle draw tools, undo, redo, settings, hide menus;
//   - top toolbar (hidden initially, Android `visibility="invisible"`): cascading menus
//     for Action / add method / line type / Change From→To / Delete type, help, overflow;
//   - by-value column: angle + length rows and the Get Angle / Get Length / Draw Line spinner;
//   - pink FAB with the labelled mini actions Export / Fold / Check.
//
// Look follows `src/css/editor.css`: light-grey (#f5f5f5) floating bars, 2 dp corners
// (the main bar's top corners are square), elevation 4, 48/56 dp heights. Icon colours
// and the action label/condensed-label typography come from `EditorChromeStyle`.
import SwiftUI

// MARK: - Shared toolbar pieces

/// One toolbar button with an optional leading icon and text label (`.editor-toolbar-button`).
///
/// CSS: `display:inline-flex; align-items:center; gap:4px; min-height:48px; padding:0 8px;
/// font-size:15px`. The action method button overrides the padding to `0 6px`; the condensed
/// line-type/delete-type label is `font-weight:500; min-width:12px; text-align:center`.
struct EditorToolbarButtonLabel: View {
    var icon: String?
    var label: String?
    var horizontalPadding: CGFloat = 8
    var condensed: Bool = false
    var caret: Bool = false
    /// Action icons are monochrome (`currentColor`); tool/line-type icons keep their
    /// original full-colour artwork.
    var iconRole: EditorIconRole = .active
    /// AppCompat ActionMenuItemView cell width (`minWidth=48dp` for icon-only items).
    var minWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                EditorIcon(name: icon, size: 24, role: iconRole)
            }
            if let label {
                Text(label)
                    .font(.system(size: 15, weight: condensed ? .medium : .regular))
                    .foregroundColor(OrTheme.textPrimary)
                    .lineLimit(1)
                    .frame(minWidth: condensed ? 12 : nil)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 2)
            }
            if caret {
                // Inherits the button's text colour on Android (`currentColor`).
                EditorIcon(name: "ic_arrow_drop_right_black_24dp", size: 20, role: .textPrimary)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(minWidth: minWidth > 0 ? minWidth : nil,
               minHeight: OrTheme.listItemHeight)
        .contentShape(Rectangle())
    }
}

/// Floating light-grey bar background (`.editor-main-toolbar` / `.editor-top-toolbar` /
/// `.editor-by-value-container`): `padding: 0 4px`, 2 dp radius, elevation 4.
struct FloatingBar<Content: View>: View {
    var minHeight: CGFloat
    var cornerRadius: CGFloat = 2
    /// The main action bar is anchored to the top edge and only rounds its bottom corners.
    var topCornersSquare: Bool = false
    @ViewBuilder var content: Content

    private var shape: AnyShape {
        if topCornersSquare {
            AnyShape(UnevenRoundedRectangle(topLeadingRadius: 0,
                                            bottomLeadingRadius: cornerRadius,
                                            bottomTrailingRadius: cornerRadius,
                                            topTrailingRadius: 0))
        } else {
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    var body: some View {
        content
            .padding(.horizontal, 4)
            .frame(minHeight: minHeight)
            // The CSS box-shadow belongs to the bar background only. Applying `.shadow`
            // to the composed view would draw the icons' own silhouettes behind their
            // translucent glyphs and darken them.
            .background(shape.fill(OrTheme.primary).editorElevation4())
    }
}

// MARK: - Main toolbar

/// `main_toolbar` (paint_cp_action_bar): centred under the safe area, top corners square.
struct PaintMainToolbar: View {
    var canUndo: Bool
    var canRedo: Bool
    var onDone: () -> Void
    var onToggleDrawTools: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onSettings: () -> Void
    var onHideMenus: () -> Void

    var body: some View {
        FloatingBar(minHeight: 56, topCornersSquare: true) {
            HStack(spacing: 0) {
                EditorIconButton(icon: "ic_done_dark_24dp", title: PaintStrings.navigateUp,
                                 action: onDone)
                EditorIconButton(icon: "ic_brush_dark_24dp", title: PaintStrings.toggleDrawTools,
                                 action: onToggleDrawTools)
                EditorIconButton(icon: "ic_undo_dark_24dp", title: PaintStrings.undo,
                                 isEnabled: canUndo, action: onUndo)
                EditorIconButton(icon: "ic_redo_dark_24dp", title: PaintStrings.redo,
                                 isEnabled: canRedo, action: onRedo)
                EditorIconButton(icon: "ic_settings_dark_24dp", title: PaintStrings.settings,
                                 action: onSettings)
                EditorIconButton(icon: "ic_unfold_less_dark_24dp", title: PaintStrings.hideMenus,
                                 action: onHideMenus)
            }
        }
    }
}

// MARK: - Top toolbar (cascading menus)

struct PaintTopToolbar: View {
    @ObservedObject var menu: PaintMenuModel

    var onAction: (Int) -> Void
    var onMethod: (Int) -> Void
    var onLineType: (Int) -> Void
    var onChangeFrom: (Int) -> Void
    var onChangeTo: (Int) -> Void
    var onDeleteType: (Int) -> Void
    var onHelp: () -> Void
    var onClearSelection: () -> Void
    var onSelectAll: () -> Void
    var onDeselectAll: () -> Void
    var onDeleteSelected: () -> Void

    private var action: PaintActionItem { menu.currentAction }

    var body: some View {
        FloatingBar(minHeight: 48) {
            HStack(spacing: 0) {
                // Action (AppCompat ActionBar spinner with the current icon+title).
                OrMenuAnchor(items: actionMenuItems) {
                    EditorToolbarButtonLabel(icon: action.icon, label: action.title)
                }
                .accessibilityLabel(Text(PaintStrings.allActions))
                .help(PaintStrings.allActions)

                switch action.action {
                case .add:
                    methodButton
                    lineTypeButton
                case .change:
                    changeFromButton
                    // `.editor-toolbar-arrow.m-disabled { color: inactive; opacity: .7 }`.
                    EditorIcon(name: "ic_arrow_forward_dark_24dp", size: 24, role: .disabled)
                        .padding(.horizontal, 2)
                    changeToButton
                case .delete:
                    deleteTypeButton
                case .select, .deleteVertex:
                    EmptyView()
                }

                EditorIconButton(icon: "ic_help_outline_dark_24dp", title: PaintStrings.help,
                                 action: onHelp)

                if let overflowItems {
                    OrMenuIconButton(icon: "ic_more_vert_dark_24dp",
                                     title: PaintStrings.moreOptions,
                                     items: overflowItems,
                                     // Opaque tint so the baked 54 % alpha stays at 54 %.
                                     tint: .black)
                }
            }
        }
    }

    // MARK: Menu definitions

    private var actionMenuItems: [OrMenuItem] {
        PaintTools.actions.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       kind: .radio,
                       checked: item.id == menu.drawActionId,
                       action: { onAction(item.id) })
        }
    }

    private var methodMenuItems: [OrMenuItem] {
        PaintTools.methods.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       // The APK popup keeps the tool illustration colours.
                       preservesIconColor: true,
                       kind: .radio,
                       checked: item.id == menu.addMethodId,
                       action: { onMethod(item.id) })
        }
    }

    private var lineTypeMenuItems: [OrMenuItem] {
        PaintTools.lineTypes.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       // `ic_oripa_line_mountain` etc. are solid coloured squares.
                       preservesIconColor: true,
                       kind: .radio,
                       checked: item.id == menu.addLineTypeId,
                       action: { onLineType(item.id) })
        }
    }

    private var changeFromItems: [OrMenuItem] {
        PaintTools.changeFrom.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       preservesIconColor: true,
                       kind: .radio,
                       checked: item.id == menu.changeFromId,
                       action: { onChangeFrom(item.id) })
        }
    }

    private var changeToItems: [OrMenuItem] {
        PaintTools.changeTo.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       preservesIconColor: true,
                       kind: .radio,
                       checked: item.id == menu.changeToId,
                       action: { onChangeTo(item.id) })
        }
    }

    private var deleteTypeItems: [OrMenuItem] {
        PaintTools.deleteTypes.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       preservesIconColor: true,
                       kind: .radio,
                       checked: item.id == menu.deleteTypeId,
                       action: { onDeleteType(item.id) })
        }
    }

    private var overflowItems: [OrMenuItem]? {
        switch action.action {
        case .add:
            return [OrMenuItem(label: PaintStrings.clearSelection, action: onClearSelection)]
        case .select:
            return [
                OrMenuItem(label: PaintStrings.selectAll, action: onSelectAll),
                OrMenuItem(label: PaintStrings.deselectAll, action: onDeselectAll),
                OrMenuItem(label: PaintStrings.deleteSelected, action: onDeleteSelected),
            ]
        default:
            return nil
        }
    }

    // MARK: Buttons

    /// AppCompat action item: 48 dp cell with the 24 dp icon centred. The APK's method /
    /// line-type / From / To / Delete-type spinners are icon-only (`showAsAction="always"`);
    /// selecting an entry calls `setIcon(menuItem.getIcon())`, so the cell shows the
    /// entry's own drawable — for the line types the solid coloured square
    /// (`ic_oripa_line_mountain` #FF0000, valley #0000FF, flat #00FFFF, boundary black)
    /// and for From/To/Delete the `ic_oripa_line_any` / `ic_oripa_line_flip` artwork.
    private func menuIconButton(_ icon: String, items: [OrMenuItem],
                                title: String) -> some View {
        OrMenuAnchor(items: items) {
            EditorToolbarButtonLabel(icon: icon, label: nil, horizontalPadding: 12,
                                     iconRole: .original, minWidth: 48)
        }
        .accessibilityLabel(Text(title))
        .help(title)
    }

    private var methodButton: some View {
        menuIconButton(menu.currentMethod.icon, items: methodMenuItems,
                       title: PaintStrings.addMethodTitle)
    }

    private var lineTypeButton: some View {
        menuIconButton(menu.currentLineType.icon, items: lineTypeMenuItems,
                       title: PaintStrings.lineTypeTitle)
    }

    private var changeFromButton: some View {
        menuIconButton(menu.currentChangeFrom.icon, items: changeFromItems,
                       title: PaintStrings.fromTitle)
    }

    private var changeToButton: some View {
        menuIconButton(menu.currentChangeTo.icon, items: changeToItems,
                       title: PaintStrings.toTitle)
    }

    private var deleteTypeButton: some View {
        let item = menu.currentDeleteType
        return menuIconButton(item.icon, items: deleteTypeItems, title: item.title)
    }
}

// MARK: - By-value column

/// `draw_method_by_value_container`: angle row, length row, by-value spinner.
struct PaintByValueColumn: View {
    @ObservedObject var menu: PaintMenuModel

    var onAngleTap: () -> Void
    var onLengthTap: () -> Void
    var onByValueEntrySelected: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            row {
                Button(action: onAngleTap) {
                    HStack(spacing: 8) {
                        EditorIcon(name: "ic_angle_dark_v2_24px", size: 24,
                                   role: .textPrimary)
                        Text(menu.byValueAngleText)
                            .font(.system(size: 16))
                            .foregroundColor(OrTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        EditorIcon(name: "ic_edit_dark_24dp", size: 24)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(EditorRowButtonStyle())
            }
            row {
                Button(action: onLengthTap) {
                    HStack(spacing: 8) {
                        EditorIcon(name: "ic_straighten_dark_24dp", size: 24,
                                   role: .textPrimary)
                        Text(menu.byValueLengthText)
                            .font(.system(size: 16))
                            .foregroundColor(OrTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        EditorIcon(name: "ic_edit_dark_24dp", size: 24)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(EditorRowButtonStyle())
            }
            row(last: true) {
                OrMenuAnchor(items: byValueMenuItems) {
                    HStack(spacing: 8) {
                        // Full-colour tool icon (grey plate + red/blue segment).
                        EditorIcon(name: menu.byValueEntry.icon, size: 24, role: .original)
                        Text(menu.byValueEntry.label)
                            .font(.system(size: 16))
                            .foregroundColor(OrTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // The spinner caret inherits the button text colour on Android.
                        EditorIcon(name: "ic_arrow_drop_right_black_24dp",
                                   size: 20, role: .textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
            }
        }
        .frame(width: 190)
        .background(RoundedRectangle(cornerRadius: 2)
            .fill(OrTheme.primary)
            .editorElevation4())
    }

    /// `by_value_spinner` is an AppCompat `Spinner` with `TextIconAdapter`
    /// (`list_item_icon_text`): its dropdown has no radio/check mark, unlike the toolbar
    /// submenus (`checkableBehavior="single"`). The current entry is shown in the spinner
    /// row itself.
    private var byValueMenuItems: [OrMenuItem] {
        PaintTools.ByValueEntry.allCases.map { entry in
            OrMenuItem(label: entry.label,
                       icon: entry.icon,
                       preservesIconColor: true,
                       kind: .normal,
                       checked: entry.rawValue == menu.byValueIndex,
                       action: { onByValueEntrySelected(entry.rawValue) })
        }
    }

    @ViewBuilder
    private func row<Content: View>(last: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
            if !last {
                Rectangle().fill(OrTheme.divider).frame(height: 1)
            }
        }
    }
}

// MARK: - FAB mini menu

/// `paint_cp_fab_mini`: pink FAB with labelled Export / Fold / Check actions.
///
/// The APK hosts them in `widget/FabMenu`: a 56 dp accent FAB that turns grey_300 with a
/// dark close icon while three right-aligned 40 dp mini FABs with grey_800 label pills are
/// stacked above it. `OrFABMenu` reproduces that widget.
struct PaintFab: View {
    var onExport: () -> Void
    var onFold: () -> Void
    var onCheck: () -> Void
    /// Snapshot/QA hook: render the expanded mini menu immediately.
    var initiallyOpen: Bool = false

    var body: some View {
        OrFABMenu(icon: "ic_flash_on_light_24dp",
                  title: PaintStrings.fabDescription,
                  items: [
                    OrFabMenuItem(icon: "ic_file_download_light_24dp",
                                  title: PaintStrings.fabExport, action: onExport),
                    OrFabMenuItem(icon: "ic_oripa_fold_cp_v2",
                                  title: PaintStrings.fabFold, action: onFold),
                    OrFabMenuItem(icon: "ic_oripa_check_cp_v2",
                                  title: PaintStrings.fabCheck, action: onCheck),
                  ],
                  initiallyOpen: initiallyOpen)
    }
}

// MARK: - "Show Menus" affordance

/// `.editor-show-menus`: a transparent 48 dp icon button at top/right offset 4 dp.
struct ShowMenusButton: View {
    var action: () -> Void

    var body: some View {
        EditorIconButton(icon: "ic_unfold_more_dark_24dp", title: PaintStrings.showMenus,
                         action: action)
    }
}
