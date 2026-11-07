// Material floating action button (+ labelled mini-action menu).
//
// Port of `M.fab` / `M.fabMenu` from `src/js/ui/components/material.js` and the `.m-fab*`
// rules of `src/css/components.css`: 56 dp accent circle (40 dp mini), white elevation,
// and the Android FabMenu variant where the FAB expands into labelled mini FABs over a
// light scrim (used by the editor's "CP Options" button).
import SwiftUI

// MARK: - FAB

/// Material floating action button.
public struct OrFAB: View {
    public var icon: String
    public var title: String
    public var isMini: Bool
    public var action: () -> Void

    public init(icon: String = "ic_add_light_24dp",
                title: String,
                isMini: Bool = false,
                action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isMini = isMini
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            MaterialIcon(icon, size: 24, tint: .white)
                .frame(width: isMini ? OrTheme.fabMiniSize : OrTheme.fabSize,
                       height: isMini ? OrTheme.fabMiniSize : OrTheme.fabSize)
                .background(OrTheme.accent)
                .clipShape(Circle())
                .orElevation(isMini ? 4 : 8)
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

/// FAB that expands into labelled mini FABs. Place it as a full-size overlay of the
/// screen content (`ZStack`/`.overlay`); it anchors itself to the bottom trailing corner.
public struct OrFABMenu: View {
    public var icon: String
    public var title: String
    public var items: [OrFabMenuItem]
    public var mainAction: (() -> Void)?

    @State private var isOpen = false

    public init(icon: String = "ic_add_light_24dp",
                title: String,
                items: [OrFabMenuItem],
                mainAction: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.items = items
        self.mainAction = mainAction
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isOpen {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
            }
            VStack(alignment: .trailing, spacing: 12) {
                if isOpen {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Text(item.title)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: 0x1E1E1E, opacity: 0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .orElevation(4)
                            OrFAB(icon: item.icon, title: item.title, isMini: true) {
                                close()
                                DispatchQueue.main.async {
                                    item.action()
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeOut(duration: 0.14).delay(Double(index) * 0.025),
                                   value: isOpen)
                    }
                }
                OrFAB(icon: icon, title: title) {
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

    private func close() {
        withAnimation(.easeOut(duration: 0.14)) { isOpen = false }
    }
}
