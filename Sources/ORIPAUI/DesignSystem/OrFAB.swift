// Material floating action button (+ the Android `FabMenu` mini-action menu).
//
// Reference: the APK's `widget/FabMenu.java`, `res/layout/fab_menu_single_item.xml` and
// the `design_fab_*` support-library dimensions (not the JS port's `.m-fab*` rules):
//   * main FAB: 56 dp accent circle with a 24 dp white icon (`ic_flash_on_light_24dp`);
//   * open state: the FAB turns grey_300 (#e0e0e0) and shows the dark close icon
//     (`ic_close_dark_24dp`) while the mini actions are visible;
//   * mini actions: 40 dp accent FABs with 24 dp white icons, each preceded by a
//     grey_800 label pill (2 dp radius, 8 dp padding, 14 sp white text), right aligned;
//   * the layout mirrors `fab_menu_single_item.xml`: 12 dp horizontal padding per row and
//     stacked at the Material mini-FAB pitch.  The 40 dp mini FAB is the *visible* circle;
//     `app:useCompatPadding="true"` adds 12 dp horizontal / 18 dp vertical shadow padding
//     (elevation 6 dp + pressed translation 6 dp), which is where the 76.6 dp row pitch and
//     the 24.4 dp trailing circle inset of the reference come from;
//   * tapping a row performs its action, tapping anywhere else closes the menu.  The
//     reference popup window has no dimming scrim.
import SwiftUI

// MARK: - FAB

/// Material floating action button.
public struct OrFAB: View {
    public var icon: String
    public var title: String
    public var isMini: Bool
    /// `backgroundTint`: colorAccent normally, grey_300 while the FabMenu is expanded.
    public var background: Color
    /// Icon tint; white on the accent FAB, 54 % black (`iconActive`) on grey_300.
    public var iconTint: Color
    public var action: () -> Void

    public init(icon: String = "ic_add_light_24dp",
                title: String,
                isMini: Bool = false,
                background: Color = OrTheme.accent,
                iconTint: Color = .white,
                action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isMini = isMini
        self.background = background
        self.iconTint = iconTint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            MaterialIcon(icon, size: 24, tint: iconTint)
                .frame(width: isMini ? OrTheme.fabMiniSize : OrTheme.fabSize,
                       height: isMini ? OrTheme.fabMiniSize : OrTheme.fabSize)
                .background(background)
                .clipShape(Circle())
                // CSS `.m-fab { box-shadow: 0 3px 8px rgba(0,0,0,.28),
                // 0 1px 3px rgba(0,0,0,.18) }` (not one of the m-elevation utilities).
                .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 3)
                .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .help(title)
    }
}

// MARK: - FAB menu

/// One labelled mini action of the FAB menu (Android FabMenu item).
public struct OrFabMenuItem: Identifiable {
    public let id = UUID()
    public var icon: String
    public var title: String
    public var action: () -> Void

    public init(icon: String, title: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }
}

/// FAB that expands into labelled mini FABs (the APK `FabMenu` widget). Place it as a
/// full-size overlay of the screen content (`ZStack`/`.overlay`); it anchors itself to the
/// bottom trailing corner.
public struct OrFABMenu: View {
    public var icon: String
    public var title: String
    public var items: [OrFabMenuItem]
    public var mainAction: (() -> Void)?

    /// QA / snapshot hook: start with the mini actions expanded (no animation).
    public var initiallyOpen: Bool

    @State private var isOpen: Bool

    public init(icon: String = "ic_add_light_24dp",
                title: String,
                items: [OrFabMenuItem],
                mainAction: (() -> Void)? = nil,
                initiallyOpen: Bool = false) {
        self.icon = icon
        self.title = title
        self.items = items
        self.mainAction = mainAction
        self.initiallyOpen = initiallyOpen
        _isOpen = State(initialValue: initiallyOpen)
    }

    // APK FabMenu geometry (dp).
    /// Visible mini FAB circle (`design_fab_size_mini`).
    private let miniFabSize: CGFloat = 40
    /// `Design_fab_shadow` vertical padding: elevation(6) + pressedTranslationZ(6) gives
    /// 12 dp, and `ShadowDrawableWrapper.calculateVerticalPadding` is 1.5 × that = 18 dp.
    private let miniFabVerticalPadding: CGFloat = 18.3
    /// Horizontal shadow padding (`calculateHorizontalPadding` = elevation = 12 dp).
    private let miniFabTrailingInset: CGFloat = 8.4 // 24.4 dp circle inset − 16 dp margin
    /// `fab_mini_wrapper_horizontal_margin` (12 dp) sits between the label and the circle.
    private let labelGap: CGFloat = 12.2
    /// 40 + 2 × 18.3 dp — the mini FAB layout height, i.e. the reference row pitch.
    private var rowHeight: CGFloat { miniFabSize + 2 * miniFabVerticalPadding }
    /// Distance from the last mini FAB circle to the main FAB (≈35 dp in the reference).
    private let menuToFabGap: CGFloat = 16.7
    /// `@dimen/fab_mini_text_margin` (8 dp) and `background_rounded_mini_fab_text`.
    private let labelPadding: CGFloat = 8
    private let labelBackground = Color(hex: 0x424242) // grey_800

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isOpen {
                // The Android popup window is full-screen, focusable and undimmed: any tap
                // outside the mini actions dismisses it.
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { close() }
            }
            VStack(alignment: .trailing, spacing: 0) {
                if isOpen {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            fabRow(item)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .animation(.easeOut(duration: 0.14).delay(Double(index) * 0.025),
                                           value: isOpen)
                        }
                    }
                    .padding(.trailing, miniFabTrailingInset)
                    .padding(.bottom, menuToFabGap)
                }
                OrFAB(icon: isOpen ? "ic_close_dark_24dp" : icon,
                      title: title,
                      background: isOpen ? OrTheme.selectedItemBackground : OrTheme.accent,
                      iconTint: isOpen ? OrTheme.iconActive : .white) {
                    if let mainAction, items.isEmpty {
                        mainAction()
                    } else {
                        withAnimation(.easeOut(duration: 0.14)) { isOpen.toggle() }
                    }
                }
            }
            .padding(OrTheme.fabMargin)
        }
    }

    /// `fab_menu_single_item`: `[grey_800 label pill][12 dp][40 dp mini FAB]`, the whole row
    /// being the click target (the Android item view owns the click listener), vertically
    /// centred in the mini-FAB layout box.
    private func fabRow(_ item: OrFabMenuItem) -> some View {
        Button {
            close()
            DispatchQueue.main.async {
                item.action()
            }
        } label: {
            HStack(spacing: 0) {
                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(labelPadding)
                    .background(RoundedRectangle(cornerRadius: 2).fill(labelBackground))
                Spacer().frame(width: labelGap)
                miniFab(item)
            }
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.title))
    }

    /// Non-interactive mini FAB body (the row button owns the tap).
    private func miniFab(_ item: OrFabMenuItem) -> some View {
        MaterialIcon(item.icon, size: 24, tint: .white)
            .frame(width: miniFabSize, height: miniFabSize)
            .background(OrTheme.accent)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.20), radius: 2.5, x: 0, y: 2)
            .shadow(color: .black.opacity(0.14), radius: 1, x: 0, y: 1)
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.14)) { isOpen = false }
    }
}
