// Material popup menu with cascading submenus.
//
// Reference: the original APK's AppCompat `PopupMenu` (`abc_popup_menu_item_layout.xml`
// + `Widget.AppCompat.Light.PopupMenu`) rather than the JS port's `.m-menu`:
//   * white content-sized card (min 140 dp, max 280 dp), 2 dp radius, elevation;
//   * 48 dp rows, 16 dp horizontal padding, leading 24 dp icon;
//   * single-choice (`checkableBehavior="single"`) rows render a Material radio button at
//     the trailing edge — accent ring + dot when checked, #757575 ring when not (the APK
//     screenshots show `Add Line` etc. with radios, not check marks);
//   * a chevron for cascading submenus (kept for the JS menu API).
// Menus are presented in a root-level overlay (`OrMenuHost`), so they are never clipped by
// a scrolling container, exactly like the Android popup window.
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Model

/// One entry of a Material popup menu (divider entries included).
public struct OrMenuItem: Identifiable {
    public enum Kind: Hashable {
        case normal
        /// Single-choice row: always draws the trailing Material radio button
        /// (checked = accent, unchecked = grey ring).
        case radio
        /// Legacy checkbox row: draws a check mark only when `checked`.
        case check
    }

    public let id: UUID
    public var label: String
    public var icon: String?
    /// Keep the drawable's own colours (ORIPA tool / line-type icons) instead of the
    /// monochrome Material icon tint. The APK popups render
    /// `ic_oripa_line_mountain`…`ic_oripa_line_any` and the tool illustrations untinted.
    public var preservesIconColor: Bool
    public var kind: Kind
    public var checked: Bool
    public var enabled: Bool
    public var submenu: [OrMenuItem]?
    public var isDivider: Bool
    public var action: (() -> Void)?

    public init(label: String,
                icon: String? = nil,
                preservesIconColor: Bool = false,
                kind: Kind = .normal,
                checked: Bool = false,
                enabled: Bool = true,
                submenu: [OrMenuItem]? = nil,
                action: (() -> Void)? = nil) {
        self.id = UUID()
        self.label = label
        self.icon = icon
        self.preservesIconColor = preservesIconColor
        self.kind = kind
        self.checked = checked
        self.enabled = enabled
        self.submenu = submenu
        self.isDivider = false
        self.action = action
    }

    private init(divider: Bool) {
        self.id = UUID()
        self.label = ""
        self.icon = nil
        self.preservesIconColor = false
        self.kind = .normal
        self.checked = false
        self.enabled = true
        self.submenu = nil
        self.isDivider = true
        self.action = nil
    }

    /// `{ divider: true }` entry, rendered as a 1 dp line with 8 dp vertical margins.
    public static func divider() -> OrMenuItem { OrMenuItem(divider: true) }
}

/// An open menu: the anchor rect in global screen coordinates + the item tree.
public struct OrMenuPresentation: Identifiable {
    public let id = UUID()
    public var anchor: CGRect
    public var items: [OrMenuItem]

    public init(anchor: CGRect, items: [OrMenuItem]) {
        self.anchor = anchor
        self.items = items
    }
}

// MARK: - Center

/// Presentation state for the single open popup menu (the JS port allows one menu at a time).
@MainActor
public final class OrMenuCenter: ObservableObject {
    @Published public private(set) var presented: OrMenuPresentation?

    public init() {}

    public var isOpen: Bool { presented != nil }

    public func show(anchor: CGRect, items: [OrMenuItem]) {
        presented = OrMenuPresentation(anchor: anchor, items: items)
    }

    public func toggle(anchor: CGRect, items: [OrMenuItem]) {
        if presented != nil {
            presented = nil
        } else {
            presented = OrMenuPresentation(anchor: anchor, items: items)
        }
    }

    public func dismiss() {
        presented = nil
    }
}

// MARK: - Anchor helpers

private struct OrGlobalFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

private extension View {
    func orCaptureGlobalFrame(into binding: Binding<CGRect>) -> some View {
        self.background(
            GeometryReader { proxy in
                Color.clear.preference(key: OrGlobalFramePreferenceKey.self,
                                       value: proxy.frame(in: .global))
            }
        )
        .onPreferenceChange(OrGlobalFramePreferenceKey.self) { frame in
            if frame != .zero { binding.wrappedValue = frame }
        }
    }
}

/// Wraps arbitrary content and opens a popup menu anchored to it (Material `M.menu(anchorEl, …)`).
public struct OrMenuAnchor<Content: View>: View {
    public var items: [OrMenuItem]
    public var isEnabled: Bool
    private let content: Content
    @State private var frame: CGRect = .zero
    @EnvironmentObject private var menus: OrMenuCenter

    public init(items: [OrMenuItem],
                isEnabled: Bool = true,
                @ViewBuilder content: () -> Content) {
        self.items = items
        self.isEnabled = isEnabled
        self.content = content()
    }

    public var body: some View {
        Button {
            guard isEnabled else { return }
            menus.toggle(anchor: frame, items: items)
        } label: {
            content
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .orCaptureGlobalFrame(into: $frame)
    }
}

/// Icon button that opens a popup menu (toolbar overflow / project item overflow).
public struct OrMenuIconButton: View {
    public var icon: String
    public var title: String
    public var items: [OrMenuItem]
    public var size: CGFloat
    public var iconSize: CGFloat
    public var tint: Color
    public var isEnabled: Bool

    public init(icon: String,
                title: String = "More options",
                items: [OrMenuItem],
                size: CGFloat = OrTheme.iconButtonSize,
                iconSize: CGFloat = 24,
                tint: Color = OrTheme.iconActive,
                isEnabled: Bool = true) {
        self.icon = icon
        self.title = title
        self.items = items
        self.size = size
        self.iconSize = iconSize
        self.tint = tint
        self.isEnabled = isEnabled
    }

    public var body: some View {
        OrMenuAnchor(items: items, isEnabled: isEnabled) {
            MaterialIcon(icon, size: iconSize, tint: isEnabled ? tint : OrTheme.iconInactive)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(title))
        .help(title)
    }
}

// MARK: - Menu metrics

/// Popup geometry shared by the width estimate and the row layout (all dp/pt).
enum OrMenuMetrics {
    /// `?attr/listPreferredItemHeightSmall` — 48 dp menu row.
    static let rowHeight: CGFloat = 48
    /// `?attr/listPreferredItemPaddingLeft` — 16 dp content inset.
    static let horizontalPadding: CGFloat = 16
    /// Menu item icon (`?attr/listMenuViewItemIconSize` equivalent in the APK layouts).
    static let iconSize: CGFloat = 24
    /// Gap between the icon and the label.
    static let iconGap: CGFloat = 16
    /// Trailing radio / check mark (`abc_btn_radio_material` intrinsic width is 20 dp).
    static let markSize: CGFloat = 20
    /// Minimum gap between the label and the trailing mark.
    static let markGap: CGFloat = 16
    /// `abc_popup_menu_item_layout.xml` `android:minWidth="196dip"` is the AppCompat list
    /// item floor; the port uses the design-system card floor/cap instead.
    static let minWidth: CGFloat = 140
    static let maxWidth: CGFloat = 280
    /// Label text style (`textAppearanceLargePopupMenu` → `TextAppearance.AppCompat.Menu`).
    static let labelFontSize: CGFloat = 16

    /// System-font width of one menu label at the 16 sp menu style.
    static func textWidth(_ text: String) -> CGFloat {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: labelFontSize)
        return (text as NSString).size(withAttributes: [.font: font]).width
        #elseif canImport(AppKit)
        let font = NSFont.systemFont(ofSize: labelFontSize)
        return (text as NSString).size(withAttributes: [.font: font]).width
        #else
        return CGFloat(text.count) * labelFontSize * 0.55
        #endif
    }

    /// Intrinsic card width for a set of rows (`content-sized`, clamped).
    static func cardWidth(items: [OrMenuItem]) -> CGFloat {
        var widest: CGFloat = 0
        for item in items where !item.isDivider {
            var width = horizontalPadding
            if iconColumnVisible(items) { width += iconSize + iconGap }
            width += textWidth(item.label) + 2 // metric slack for SwiftUI text layout
            if trailingMark(item) { width += markGap + markSize }
            width += horizontalPadding
            widest = max(widest, width)
        }
        return min(maxWidth, max(minWidth, ceil(widest)))
    }

    /// The APK popup only reserves the leading icon column when the menu has icons.
    static func iconColumnVisible(_ items: [OrMenuItem]) -> Bool {
        items.contains { $0.icon != nil }
    }

    static func trailingMark(_ item: OrMenuItem) -> Bool {
        if item.submenu != nil { return true }
        switch item.kind {
        case .radio: return true
        case .check: return item.checked
        case .normal: return false
        }
    }
}

// MARK: - Menu rendering

/// Root-level overlay that draws the currently presented menu above everything else.
public struct OrMenuHost: View {
    @ObservedObject public var center: OrMenuCenter

    public init(center: OrMenuCenter) {
        self.center = center
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let presentation = center.presented {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { center.dismiss() }
                    OrMenuList(items: presentation.items,
                               anchor: presentation.anchor,
                               container: proxy.size,
                               onDismiss: { center.dismiss() })
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}

/// A single menu level. Submenus are rendered recursively as siblings to the right.
struct OrMenuList: View {
    var items: [OrMenuItem]
    var anchor: CGRect
    var container: CGSize
    var onDismiss: () -> Void

    @State private var submenu: OrMenuSubmenuState?

    private var estimatedWidth: CGFloat { OrMenuMetrics.cardWidth(items: items) }

    private var estimatedHeight: CGFloat {
        let rows = items.reduce(CGFloat(0)) { partial, item in
            partial + (item.isDivider ? 17 : OrMenuMetrics.rowHeight)
        }
        return rows
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            menuSurface
                .offset(x: origin.x, y: origin.y)
            if let submenu {
                OrMenuList(items: submenu.items,
                           anchor: submenu.anchor,
                           container: container,
                           onDismiss: onDismiss)
            }
        }
    }

    private var origin: CGPoint {
        var x = anchor.maxX - 4
        var y = anchor.maxY + 2
        if x + estimatedWidth > container.width - 8 {
            x = max(8, container.width - estimatedWidth - 8)
        }
        if y + estimatedHeight > container.height - 8 {
            // JS: `y = Math.max(8, y - mh)` with y = anchor.bottom + 2.
            y = max(8, y - estimatedHeight)
        }
        return CGPoint(x: round(x), y: round(y))
    }

    private var menuSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                if item.isDivider {
                    OrDivider()
                        .padding(.vertical, 8)
                } else {
                    OrMenuRow(item: item,
                              showsIconColumn: OrMenuMetrics.iconColumnVisible(items),
                              onActivate: { handle(item) },
                              onSubmenu: item.submenu != nil
                                  ? { openSubmenu(item, rowOriginY: nil) }
                                  : nil)
                }
            }
        }
        .frame(width: estimatedWidth, alignment: .leading)
        .background(OrTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        // Flatten before the drop shadow, otherwise SwiftUI also shadows each label and
        // the menu text gets a visible halo.
        .compositingGroup()
        .orElevation(8)
    }

    private func handle(_ item: OrMenuItem) {
        if item.submenu != nil {
            openSubmenu(item, rowOriginY: nil)
            return
        }
        guard item.enabled else { return }
        onDismiss()
        item.action?()
    }

    private func openSubmenu(_ item: OrMenuItem, rowOriginY: CGFloat?) {
        guard let subItems = item.submenu else { return }
        let menuOrigin = origin
        let rowIndex = items.firstIndex(where: { $0.id == item.id }) ?? 0
        var y = menuOrigin.y
        for index in 0..<min(rowIndex, items.count) {
            y += items[index].isDivider ? 17 : OrMenuMetrics.rowHeight
        }
        let rowRect = CGRect(x: menuOrigin.x, y: y,
                             width: estimatedWidth, height: OrMenuMetrics.rowHeight)
        submenu = OrMenuSubmenuState(items: subItems, anchor: rowRect)
    }
}

private struct OrMenuSubmenuState {
    var items: [OrMenuItem]
    var anchor: CGRect
}

private struct OrMenuRow: View {
    var item: OrMenuItem
    var showsIconColumn: Bool
    var onActivate: () -> Void
    var onSubmenu: (() -> Void)?

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 0) {
                if showsIconColumn {
                    if let icon = item.icon {
                        // Full-colour ORIPA drawables (line types, tool illustrations) keep
                        // their own colours; monochrome Material icons get the 54 % tint.
                        MaterialIcon(icon,
                                     size: OrMenuMetrics.iconSize,
                                     tint: item.preservesIconColor ? nil : OrTheme.iconActive)
                            .frame(width: OrMenuMetrics.iconSize,
                                   height: OrMenuMetrics.iconSize)
                    } else {
                        Color.clear
                            .frame(width: OrMenuMetrics.iconSize,
                                   height: OrMenuMetrics.iconSize)
                    }
                    Spacer().frame(width: OrMenuMetrics.iconGap)
                }
                Text(item.label)
                    .font(OrTheme.menuItem())
                    .foregroundColor(item.enabled ? OrTheme.textPrimary : OrTheme.textDisabled)
                    .lineLimit(1)
                Spacer(minLength: OrMenuMetrics.trailingMark(item)
                       ? OrMenuMetrics.markGap : 0)
                switch item.kind {
                case .radio:
                    // AppCompat `abc_list_menu_item_radio`: 20 dp Material radio.
                    OrRadioMark(isChecked: item.checked)
                        .frame(width: OrMenuMetrics.markSize,
                               height: OrMenuMetrics.markSize)
                case .check:
                    if item.checked {
                        MaterialIcon("ic_done_dark_24dp",
                                     size: OrMenuMetrics.markSize,
                                     tint: OrTheme.textPrimary)
                    }
                case .normal:
                    EmptyView()
                }
                if item.submenu != nil {
                    MaterialIcon("ic_chevron_right_dark_24dp", size: 20, tint: OrTheme.iconActive)
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, OrMenuMetrics.horizontalPadding)
            .frame(minHeight: OrMenuMetrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(OrMenuRowButtonStyle())
        .disabled(!item.enabled)
    }
}

private struct OrMenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.08) : Color.clear)
    }
}
