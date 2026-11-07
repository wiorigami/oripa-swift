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
// Look follows `src/css/editor.css`: light-grey (#f5f5f5) floating bars, 2 dp corners,
// elevation 4, 48/56 dp heights.
import SwiftUI

// MARK: - Shared toolbar pieces

/// One toolbar button with an optional leading icon and text label (`.editor-toolbar-button`).
struct EditorToolbarButtonLabel: View {
    var icon: String?
    var label: String?
    var condensed: Bool = false
    var caret: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                MaterialIcon(icon, size: 24, tint: OrTheme.iconActive)
            }
            if let label {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(OrTheme.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            }
            if caret {
                MaterialIcon("ic_arrow_drop_right_black_24dp", size: 20, tint: OrTheme.iconInactive)
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

/// Floating light-grey bar background (`.editor-main-toolbar` / `.editor-top-toolbar`).
struct FloatingBar<Content: View>: View {
    var minHeight: CGFloat
    var cornerRadius: CGFloat = 2
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 4)
            .frame(minHeight: minHeight)
            .background(OrTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .orElevation(4)
    }
}

// MARK: - Main toolbar

/// `main_toolbar` (paint_cp_action_bar): centred under the safe area.
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
        FloatingBar(minHeight: 56) {
            HStack(spacing: 0) {
                OrIconButton(icon: "ic_done_dark_24dp", title: PaintStrings.navigateUp,
                             action: onDone)
                OrIconButton(icon: "ic_brush_dark_24dp", title: PaintStrings.toggleDrawTools,
                             action: onToggleDrawTools)
                OrIconButton(icon: "ic_undo_dark_24dp", title: PaintStrings.undo,
                             isEnabled: canUndo, action: onUndo)
                OrIconButton(icon: "ic_redo_dark_24dp", title: PaintStrings.redo,
                             isEnabled: canRedo, action: onRedo)
                OrIconButton(icon: "ic_settings_dark_24dp", title: PaintStrings.settings,
                             action: onSettings)
                OrIconButton(icon: "ic_unfold_less_dark_24dp", title: PaintStrings.hideMenus,
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
                    MaterialIcon("ic_arrow_forward_dark_24dp", size: 24, tint: OrTheme.iconInactive)
                        .padding(.horizontal, 2)
                    changeToButton
                case .delete:
                    deleteTypeButton
                case .select, .deleteVertex:
                    EmptyView()
                }

                OrIconButton(icon: "ic_help_outline_dark_24dp", title: PaintStrings.help,
                             action: onHelp)

                if let overflowItems {
                    OrMenuIconButton(icon: "ic_more_vert_dark_24dp",
                                     title: PaintStrings.moreOptions,
                                     items: overflowItems)
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
                       kind: .radio,
                       checked: item.id == menu.addMethodId,
                       action: { onMethod(item.id) })
        }
    }

    private var lineTypeMenuItems: [OrMenuItem] {
        PaintTools.lineTypes.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       kind: .radio,
                       checked: item.id == menu.addLineTypeId,
                       action: { onLineType(item.id) })
        }
    }

    private var changeFromItems: [OrMenuItem] {
        PaintTools.changeFrom.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       kind: .radio,
                       checked: item.id == menu.changeFromId,
                       action: { onChangeFrom(item.id) })
        }
    }

    private var changeToItems: [OrMenuItem] {
        PaintTools.changeTo.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
                       kind: .radio,
                       checked: item.id == menu.changeToId,
                       action: { onChangeTo(item.id) })
        }
    }

    private var deleteTypeItems: [OrMenuItem] {
        PaintTools.deleteTypes.map { item in
            OrMenuItem(label: item.title,
                       icon: item.icon,
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

    private var methodButton: some View {
        let method = menu.currentMethod
        return OrMenuAnchor(items: methodMenuItems) {
            EditorToolbarButtonLabel(icon: method.icon, label: nil)
        }
        .accessibilityLabel(Text(PaintStrings.addMethodTitle))
        .help(PaintStrings.addMethodTitle)
    }

    private var lineTypeButton: some View {
        let type = menu.currentLineType
        return OrMenuAnchor(items: lineTypeMenuItems) {
            EditorToolbarButtonLabel(icon: nil, label: type.condensed ?? type.title)
        }
        .accessibilityLabel(Text(PaintStrings.lineTypeTitle))
        .help(PaintStrings.lineTypeTitle)
    }

    private var changeFromButton: some View {
        let item = menu.currentChangeFrom
        return OrMenuAnchor(items: changeFromItems) {
            EditorToolbarButtonLabel(icon: item.icon, label: PaintStrings.fromTitle)
        }
        .accessibilityLabel(Text(PaintStrings.fromTitle))
        .help(PaintStrings.fromTitle)
    }

    private var changeToButton: some View {
        let item = menu.currentChangeTo
        return OrMenuAnchor(items: changeToItems) {
            EditorToolbarButtonLabel(icon: item.icon, label: PaintStrings.toTitle)
        }
        .accessibilityLabel(Text(PaintStrings.toTitle))
        .help(PaintStrings.toTitle)
    }

    private var deleteTypeButton: some View {
        let item = menu.currentDeleteType
        return OrMenuAnchor(items: deleteTypeItems) {
            EditorToolbarButtonLabel(icon: item.icon, label: item.condensed ?? item.title)
        }
        .accessibilityLabel(Text(item.title))
        .help(item.title)
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
                        MaterialIcon("ic_angle_dark_v2_24px", size: 24, tint: OrTheme.iconActive)
                        Text(menu.byValueAngleText)
                            .font(.system(size: 16))
                            .foregroundColor(OrTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        MaterialIcon("ic_edit_dark_24dp", size: 24, tint: OrTheme.iconActive)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            row {
                Button(action: onLengthTap) {
                    HStack(spacing: 8) {
                        MaterialIcon("ic_straighten_dark_24dp", size: 24, tint: OrTheme.iconActive)
                        Text(menu.byValueLengthText)
                            .font(.system(size: 16))
                            .foregroundColor(OrTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        MaterialIcon("ic_edit_dark_24dp", size: 24, tint: OrTheme.iconActive)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            row(last: true) {
                OrMenuAnchor(items: byValueMenuItems) {
                    HStack(spacing: 8) {
                        MaterialIcon(menu.byValueEntry.icon, size: 24, tint: OrTheme.iconActive)
                        Text(menu.byValueEntry.label)
                            .font(.system(size: 16))
                            .foregroundColor(OrTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        MaterialIcon("ic_arrow_drop_right_black_24dp", size: 20,
                                     tint: OrTheme.iconInactive)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
            }
        }
        .frame(width: 190)
        .background(OrTheme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .orElevation(4)
    }

    private var byValueMenuItems: [OrMenuItem] {
        PaintTools.ByValueEntry.allCases.map { entry in
            OrMenuItem(label: entry.label,
                       icon: entry.icon,
                       kind: .radio,
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
struct PaintFab: View {
    var onExport: () -> Void
    var onFold: () -> Void
    var onCheck: () -> Void

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
                  ])
    }
}

// MARK: - "Show Menus" affordance

struct ShowMenusButton: View {
    var action: () -> Void

    var body: some View {
        OrIconButton(icon: "ic_unfold_more_dark_24dp", title: PaintStrings.showMenus,
                     action: action)
    }
}
