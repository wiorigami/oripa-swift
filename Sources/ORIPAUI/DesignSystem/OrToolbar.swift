// Material app bar + contextual action bar + toolbar dropdown spinner.
//
// Port of `M.toolbar`, `M.actionBar` and `M.spinner` from
// `src/js/ui/components/material.js` and the `.m-toolbar*` / `.m-action-bar*` /
// `.m-spinner*` rules of `src/css/components.css`:
//   * 56 dp bar, colorPrimary #f5f5f5, dark 54 % icons, 4 dp side padding;
//   * title 20 sp medium, single line, ellipsized;
//   * actions: always / withText / overflow (`never` -> "More options" popup menu);
//   * action mode bar: colorPrimarySelected grey_600, white icons, close + delete-with-text;
//   * toolbar spinner: label + caret + checked popup menu (AppCompat ActionBar spinner).
import SwiftUI

// MARK: - Toolbar model

public enum OrToolbarBackground: Equatable {
    /// colorPrimary app bar with elevation 4.
    case primary
    /// Preview CP gradient bar: `linear-gradient(primary 94%, transparent)`.
    case transparent
    /// Fully transparent (editor floating bars).
    case none
}

public enum OrToolbarNav {
    case back
    case close
    case none
    case custom(icon: String, title: String)
}

/// One action bar item (`res/menu/*.xml` item with showAs).
public struct OrToolbarAction: Identifiable {
    public enum ShowAs {
        case always
        /// Always in the overflow menu (AppCompat `showAsAction="never"`).
        case never
        /// Icon + condensed label (`withText`).
        case withText
    }

    public let id = UUID()
    public var icon: String?
    public var title: String
    public var condensedLabel: String?
    public var showAs: ShowAs
    public var isEnabled: Bool
    public var isVisible: Bool
    public var action: () -> Void

    public init(icon: String? = nil,
                title: String,
                condensedLabel: String? = nil,
                showAs: ShowAs = .always,
                isEnabled: Bool = true,
                isVisible: Bool = true,
                action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.condensedLabel = condensedLabel
        self.showAs = showAs
        self.isEnabled = isEnabled
        self.isVisible = isVisible
        self.action = action
    }
}

// MARK: - Toolbar

/// Material app bar. Navigation defaults to the router back (`O.ui.app.back()`).
public struct OrToolbar: View {
    private var titleView: AnyView
    private var nav: OrToolbarNav
    private var background: OrToolbarBackground
    private var actions: [OrToolbarAction]
    private var navActionOverride: (() -> Void)?
    private var titleHorizontalPadding: CGFloat

    @EnvironmentObject private var app: AppModel

    public init(title: String,
                nav: OrToolbarNav = .back,
                background: OrToolbarBackground = .primary,
                actions: [OrToolbarAction] = [],
                titlePadding: CGFloat = 4,
                onNav: (() -> Void)? = nil) {
        self.titleView = AnyView(
            Text(title)
                .font(OrTheme.toolbarTitle())
                .foregroundColor(OrTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        )
        self.nav = nav
        self.background = background
        self.actions = actions
        self.navActionOverride = onNav
        self.titleHorizontalPadding = titlePadding
    }

    public init<Title: View>(nav: OrToolbarNav = .back,
                             background: OrToolbarBackground = .primary,
                             actions: [OrToolbarAction] = [],
                             titlePadding: CGFloat = 4,
                             onNav: (() -> Void)? = nil,
                             @ViewBuilder title: () -> Title) {
        self.titleView = AnyView(title())
        self.nav = nav
        self.background = background
        self.actions = actions
        self.navActionOverride = onNav
        self.titleHorizontalPadding = titlePadding
    }

    public var body: some View {
        HStack(spacing: 0) {
            if let navButton = navigationButton {
                navButton
                    .padding(.trailing, 4)
            }
            titleView
                .padding(.horizontal, titleHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                ForEach(actions.filter { $0.isVisible && $0.showAs != .never }) { action in
                    actionView(action)
                }
                let overflow = actions.filter { $0.isVisible && $0.showAs == .never }
                if !overflow.isEmpty {
                    OrMenuIconButton(icon: "ic_more_vert_dark_24dp",
                                     title: "More options",
                                     items: overflow.map(menuItem(for:)),
                                     tint: iconTint)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 4)
        .frame(minHeight: OrTheme.toolbarHeight)
        .background(backgroundView)
        .orElevation(background == .primary ? 4 : 0)
    }

    private var iconTint: Color {
        background == .primary || background == .transparent ? OrTheme.iconActive : OrTheme.iconLight
    }

    private var titleColor: Color {
        background == .primary || background == .transparent ? OrTheme.textPrimary : OrTheme.iconLight
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch background {
        case .primary:
            OrTheme.primary
        case .transparent:
            LinearGradient(colors: [OrTheme.primary.opacity(0.94), OrTheme.primary.opacity(0)],
                           startPoint: .top,
                           endPoint: .bottom)
        case .none:
            Color.clear
        }
    }

    private var navigationButton: AnyView? {
        switch nav {
        case .none:
            return nil
        case .back:
            return AnyView(OrIconButton(icon: "ic_arrow_back_dark_24dp",
                                        title: "Navigate up",
                                        tint: iconTint) {
                performNav()
            })
        case .close:
            return AnyView(OrIconButton(icon: "ic_close_dark_24dp",
                                        title: "Close",
                                        tint: iconTint) {
                performNav()
            })
        case .custom(let icon, let title):
            return AnyView(OrIconButton(icon: icon, title: title, tint: iconTint) {
                performNav()
            })
        }
    }

    @ViewBuilder
    private func actionView(_ action: OrToolbarAction) -> some View {
        switch action.showAs {
        case .withText:
            OrIconTextButton(icon: action.icon ?? "ic_more_vert_dark_24dp",
                             title: action.title,
                             label: action.condensedLabel ?? action.title,
                             tint: iconTint,
                             labelColor: titleColor,
                             isEnabled: action.isEnabled,
                             action: action.action)
        case .always, .never:
            OrIconButton(icon: action.icon ?? "ic_more_vert_dark_24dp",
                         title: action.title,
                         tint: iconTint,
                         isEnabled: action.isEnabled,
                         action: action.action)
        }
    }

    private func menuItem(for action: OrToolbarAction) -> OrMenuItem {
        OrMenuItem(label: action.title,
                   icon: action.icon,
                   enabled: action.isEnabled,
                   action: action.action)
    }

    private func performNav() {
        if let override = navActionOverride {
            override()
        } else {
            _ = app.back()
        }
    }
}

// MARK: - Contextual action bar

/// Selection-mode action bar (`M.actionBar`): grey_600 background, white icons.
public struct OrActionBar: View {
    public var title: String
    public var closeIcon: String
    public var onClose: () -> Void
    public var actions: [OrToolbarAction]

    public init(title: String,
                closeIcon: String = "ic_close_light_24dp",
                onClose: @escaping () -> Void,
                actions: [OrToolbarAction] = []) {
        self.title = title
        self.closeIcon = closeIcon
        self.onClose = onClose
        self.actions = actions
    }

    public var body: some View {
        HStack(spacing: 0) {
            OrIconButton(icon: closeIcon, title: "Close", tint: OrTheme.iconLight, action: onClose)
                .padding(.trailing, 4)
            Text(title)
                .font(OrTheme.actionBarTitle())
                .foregroundColor(OrTheme.iconLight)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                ForEach(actions) { action in
                    OrIconTextButton(icon: action.icon ?? "ic_more_vert_dark_24dp",
                                     title: action.title,
                                     label: action.condensedLabel ?? action.title,
                                     tint: OrTheme.iconLight,
                                     labelColor: OrTheme.iconLight,
                                     isEnabled: action.isEnabled,
                                     action: action.action)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 4)
        .frame(minHeight: OrTheme.actionBarHeight)
        .background(OrTheme.primarySelected)
        .orElevation(4)
    }
}

// MARK: - Toolbar spinner

/// Item of the toolbar dropdown selector.
public struct OrSpinnerItem: Identifiable, Equatable {
    public let id = UUID()
    public var label: String
    public var icon: String?

    public init(label: String, icon: String? = nil) {
        self.label = label
        self.icon = icon
    }

    public static func == (lhs: OrSpinnerItem, rhs: OrSpinnerItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// AppCompat ActionBar spinner: current label + caret, popup menu with a check mark.
public struct OrSpinner: View {
    public var items: [OrSpinnerItem]
    public var index: Int
    public var labelColor: Color
    public var onSelect: (Int) -> Void

    public init(items: [OrSpinnerItem],
                index: Int = 0,
                labelColor: Color = OrTheme.textPrimary,
                onSelect: @escaping (Int) -> Void) {
        self.items = items
        self.index = index
        self.labelColor = labelColor
        self.onSelect = onSelect
    }

    private var currentLabel: String {
        guard items.indices.contains(index) else { return items.first?.label ?? "" }
        return items[index].label
    }

    public var body: some View {
        OrMenuAnchor(items: menuItems) {
            HStack(spacing: 2) {
                Text(currentLabel)
                    .font(.system(size: 16))
                    .foregroundColor(labelColor)
                    .lineLimit(1)
                MaterialIcon("ic_arrow_drop_down_black_24dp", size: 24, tint: OrTheme.iconActive)
            }
            .frame(minHeight: OrTheme.iconButtonSize)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(currentLabel))
    }

    private var menuItems: [OrMenuItem] {
        items.enumerated().map { offset, item in
            OrMenuItem(label: item.label,
                       icon: item.icon,
                       checked: offset == index,
                       action: { onSelect(offset) })
        }
    }
}
