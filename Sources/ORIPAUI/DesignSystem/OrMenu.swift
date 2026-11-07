// Material popup menu with cascading submenus.
//
// Port of `M.menu` / `M.clearMenus` from `src/js/ui/components/material.js` and the
// `.m-menu*` rules of `src/css/components.css`: white surface, 2 dp radius, 48 dp rows,
// 16 dp horizontal padding, leading icon, trailing check mark for radio/check items and
// a chevron for submenus. Menus are presented in a root-level overlay (`OrMenuHost`), so
// they are never clipped by a scrolling container, exactly like the JS menu layer.
import SwiftUI

// MARK: - Model

/// One entry of a Material popup menu (divider entries included).
public struct OrMenuItem: Identifiable {
    public enum Kind: Hashable {
        case normal
        case radio
        case check
    }

    public let id: UUID
    public var label: String
    public var icon: String?
    public var kind: Kind
    public var checked: Bool
    public var enabled: Bool
    public var submenu: [OrMenuItem]?
    public var isDivider: Bool
    public var action: (() -> Void)?

    public init(label: String,
                icon: String? = nil,
                kind: Kind = .normal,
                checked: Bool = false,
                enabled: Bool = true,
                submenu: [OrMenuItem]? = nil,
                action: (() -> Void)? = nil) {
        self.id = UUID()
        self.label = label
        self.icon = icon
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

    private var estimatedWidth: CGFloat {
        let longest = items.map { item -> CGFloat in
            if item.isDivider { return 0 }
            var w: CGFloat = 32 // left/right padding
            if item.icon != nil { w += 24 + 24 } else { w += 0 }
            w += CGFloat(item.label.count) * 9
            if item.checked { w += 20 + 16 }
            if item.submenu != nil { w += 20 + 16 }
            return w
        }.max() ?? 140
        return min(320, max(140, longest))
    }

    private var estimatedHeight: CGFloat {
        let rows = items.reduce(CGFloat(0)) { partial, item in
            partial + (item.isDivider ? 17 : 48)
        }
        return rows + 16
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
            y = max(8, anchor.minY - estimatedHeight)
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
                              onActivate: { handle(item) },
                              onSubmenu: item.submenu != nil
                                  ? { openSubmenu(item, rowOriginY: nil) }
                                  : nil)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: estimatedWidth, alignment: .leading)
        .background(OrTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 2))
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
        var y = menuOrigin.y + 8
        for index in 0..<min(rowIndex, items.count) {
            y += items[index].isDivider ? 17 : 48
        }
        let rowRect = CGRect(x: menuOrigin.x, y: y,
                             width: estimatedWidth, height: 48)
        submenu = OrMenuSubmenuState(items: subItems, anchor: rowRect)
    }
}

private struct OrMenuSubmenuState {
    var items: [OrMenuItem]
    var anchor: CGRect
}

private struct OrMenuRow: View {
    var item: OrMenuItem
    var onActivate: () -> Void
    var onSubmenu: (() -> Void)?

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 0) {
                if let icon = item.icon {
                    MaterialIcon(icon, size: 24, tint: OrTheme.iconActive)
                        .padding(.trailing, 24)
                }
                Text(item.label)
                    .font(OrTheme.menuItem())
                    .foregroundColor(item.enabled ? OrTheme.textPrimary : OrTheme.textDisabled)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if item.checked {
                    MaterialIcon("ic_done_dark_24dp", size: 20, tint: OrTheme.textPrimary)
                        .padding(.leading, 16)
                }
                if item.submenu != nil {
                    MaterialIcon("ic_chevron_right_dark_24dp", size: 20, tint: OrTheme.iconActive)
                        .padding(.leading, 16)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
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
