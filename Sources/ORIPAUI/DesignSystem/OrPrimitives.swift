// Small Material-Design building blocks shared by every ORIPA screen.
//
// Port of the reusable pieces of `src/js/ui/components/material.js` that are not a
// dedicated component file: icon buttons, uppercase text buttons, dividers, the Material
// switch drawing, list rows, checkboxes and the full-screen progress overlay.
import SwiftUI

// MARK: - Press feedback

/// Material "borderless" press feedback: a subtle dark tint while the control is pressed
/// (replaces the JS `.m-ripple` animation; native controls get an opacity/tint state).
public struct OrPressableButtonStyle: ButtonStyle {
    public var shape: AnyShape
    public var pressedTint: Color

    public init(shape: AnyShape = AnyShape(Circle()), pressedTint: Color = OrTheme.ripple) {
        self.shape = shape
        self.pressedTint = pressedTint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                shape
                    .fill(configuration.isPressed ? pressedTint : Color.clear)
            )
            .contentShape(shape)
            .animation(.linear(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Icon button

/// AppCompat `?android:borderlessButtonStyle` icon button: 48 × 48 dp, circular ripple.
public struct OrIconButton: View {
    public var icon: String
    public var title: String
    public var size: CGFloat
    public var iconSize: CGFloat
    public var tint: Color
    public var isEnabled: Bool
    public var action: () -> Void

    public init(icon: String,
                title: String = "",
                size: CGFloat = OrTheme.iconButtonSize,
                iconSize: CGFloat = 24,
                tint: Color = OrTheme.iconActive,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.size = size
        self.iconSize = iconSize
        self.tint = tint
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            MaterialIcon(icon, size: iconSize, tint: isEnabled ? tint : OrTheme.iconInactive)
                .frame(width: size, height: size)
        }
        .buttonStyle(OrPressableButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.7)
        .accessibilityLabel(Text(title))
        .help(title)
    }
}

/// Icon + optional condensed label (AppCompat `withText` menu item).
public struct OrIconTextButton: View {
    public var icon: String
    public var title: String
    public var label: String
    public var tint: Color
    public var labelColor: Color
    public var isEnabled: Bool
    public var action: () -> Void

    public init(icon: String,
                title: String,
                label: String? = nil,
                tint: Color = OrTheme.iconActive,
                labelColor: Color = OrTheme.textPrimary,
                isEnabled: Bool = true,
                action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.label = label ?? title
        self.tint = tint
        self.labelColor = labelColor
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                MaterialIcon(icon, size: 24, tint: isEnabled ? tint : OrTheme.iconInactive)
                Text(label.uppercased())
                    .font(OrTheme.button())
                    .kerning(0.9)
                    .foregroundColor(isEnabled ? labelColor : OrTheme.textDisabled)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(minWidth: OrTheme.iconButtonSize, minHeight: OrTheme.iconButtonSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(OrPressableButtonStyle(shape: AnyShape(RoundedRectangle(cornerRadius: 4)),
                                            pressedTint: OrTheme.ripple))
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
        .help(title)
    }
}

// MARK: - Text button

/// Material text button: uppercase, 14 sp medium, letterSpacing 0.08 em.
public struct OrTextButton: View {
    public var text: String
    public var isPrimary: Bool
    public var tint: Color?
    public var action: () -> Void

    public init(_ text: String,
                isPrimary: Bool = false,
                tint: Color? = nil,
                action: @escaping () -> Void) {
        self.text = text
        self.isPrimary = isPrimary
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(text.uppercased())
                .font(OrTheme.button())
                .kerning(1.0)
                .foregroundColor(tint ?? (isPrimary ? OrTheme.accent : OrTheme.textSecondary))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(OrPressableButtonStyle(shape: AnyShape(RoundedRectangle(cornerRadius: 2)),
                                            pressedTint: OrTheme.ripple))
    }
}

// MARK: - Divider

/// 1 dp divider in the Material divider colour.
public struct OrDivider: View {
    public var inset: CGFloat
    public init(inset: CGFloat = 0) { self.inset = inset }
    public var body: some View {
        Rectangle()
            .fill(OrTheme.divider)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

// MARK: - Material switch

/// The Material (AppCompat) switch track + thumb used by preference rows and dialogs.
public struct OrMaterialSwitch: View {
    public var isOn: Bool
    public var enabled: Bool

    public init(isOn: Bool, enabled: Bool = true) {
        self.isOn = isOn
        self.enabled = enabled
    }

    public var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? OrTheme.switchOnTrack
                           : (enabled ? OrTheme.switchOffTrack : OrTheme.switchOffTrack.opacity(0.5)))
                .frame(width: OrTheme.switchWidth, height: OrTheme.switchHeight)
            Circle()
                .fill(isOn ? OrTheme.accent : OrTheme.switchThumb)
                .frame(width: OrTheme.switchThumbSize, height: OrTheme.switchThumbSize)
                .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 1)
                .offset(x: isOn ? 3 : -3)
        }
        .frame(width: OrTheme.switchWidth + 6, height: OrTheme.switchThumbSize)
        .animation(.easeOut(duration: 0.12), value: isOn)
    }
}

// MARK: - List row / checkbox

/// Material list row (settings "list preference"-like rows outside the settings screen).
public struct OrListRow<Extra: View>: View {
    public var icon: String?
    public var title: String
    public var summary: String?
    public var showsChevron: Bool
    public var isEnabled: Bool
    public var action: (() -> Void)?
    private var extra: Extra

    public init(icon: String? = nil,
                title: String,
                summary: String? = nil,
                showsChevron: Bool = false,
                isEnabled: Bool = true,
                action: (() -> Void)? = nil,
                @ViewBuilder extra: () -> Extra) {
        self.icon = icon
        self.title = title
        self.summary = summary
        self.showsChevron = showsChevron
        self.isEnabled = isEnabled
        self.action = action
        self.extra = extra()
    }

    public init(icon: String? = nil,
                title: String,
                summary: String? = nil,
                showsChevron: Bool = false,
                isEnabled: Bool = true,
                action: (() -> Void)? = nil) where Extra == EmptyView {
        self.init(icon: icon,
                  title: title,
                  summary: summary,
                  showsChevron: showsChevron,
                  isEnabled: isEnabled,
                  action: action,
                  extra: { EmptyView() })
    }

    public var body: some View {
        let row = HStack(spacing: 16) {
            if let icon {
                MaterialIcon(icon, size: 24, tint: OrTheme.iconActive)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OrTheme.settingsTitle())
                    .foregroundColor(OrTheme.textPrimary)
                if let summary {
                    Text(summary)
                        .font(OrTheme.settingsSummary())
                        .foregroundColor(OrTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            extra
            if showsChevron {
                MaterialIcon("ic_chevron_right_dark_24dp", size: 24, tint: OrTheme.iconActive)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: OrTheme.listItemHeight)
        .contentShape(Rectangle())

        if let action {
            Button(action: { if isEnabled { action() } }, label: { row })
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.45)
        } else {
            row
        }
    }
}

/// Material checkbox row (Material check box with the accent fill).
public struct OrCheckboxRow: View {
    public var title: String?
    @Binding public var isChecked: Bool
    public var isEnabled: Bool

    public init(title: String? = nil, isChecked: Binding<Bool>, isEnabled: Bool = true) {
        self.title = title
        self._isChecked = isChecked
        self.isEnabled = isEnabled
    }

    public var body: some View {
        Button {
            guard isEnabled else { return }
            isChecked.toggle()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isChecked ? OrTheme.accent : Color.clear)
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(isChecked ? OrTheme.accent : OrTheme.iconActive, lineWidth: 2)
                    if isChecked {
                        MaterialIcon("ic_done_dark_24dp", size: 16, tint: .white)
                    }
                }
                .frame(width: 18, height: 18)
                if let title {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(OrTheme.textPrimary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: OrTheme.listItemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

// MARK: - Progress overlay

/// Full-screen progress overlay (`M.progress`): scrim + white box with a spinning ring.
public struct OrProgressOverlay: View {
    public var text: String

    public init(_ text: String = "") {
        self.text = text
    }

    public var body: some View {
        ZStack {
            OrTheme.scrim.ignoresSafeArea()
            VStack(spacing: 16) {
                OrSpinnerRing()
                if !text.isEmpty {
                    Text(text)
                        .font(OrTheme.body())
                        .foregroundColor(OrTheme.textSecondary)
                }
            }
            .padding(24)
            .frame(minWidth: 160)
            .background(OrTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .orElevation(24)
        }
        .transition(.opacity)
    }
}

/// The Material circular indeterminate spinner (`m-spinner-circle`).
public struct OrSpinnerRing: View {
    @State private var spinning = false
    public init() {}
    public var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(OrTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 36, height: 36)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
            .overlay(
                Circle()
                    .stroke(OrTheme.accent.opacity(0.2), lineWidth: 3)
            )
    }
}

// MARK: - Tooltips

public extension View {
    /// Material tooltip: a pointer hover help on macOS/iPadOS and an accessibility hint
    /// everywhere. The web port used `title` attributes on icon buttons.
    func orTooltip(_ text: String) -> some View {
        self.help(text)
            .accessibilityHint(Text(text))
    }
}
