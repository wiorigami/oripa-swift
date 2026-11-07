// Material dialog kit + root-level dialog host.
//
// Port of `M.dialog` / `M.confirm` / `M.textDialog` / `M.numberDialog` / `M.closeTopDialog`
// from `src/js/ui/components/material.js`, plus the AlertDialog chrome (icon + title,
// single-choice radio list) of `src/js/ui/dialogs/error.js`. Dialogs are presented in a
// root overlay so any screen or component can open one without owning a `.sheet` binding,
// exactly like the imperative JS API.
import SwiftUI

// MARK: - Model

/// One Material text button of a dialog (JS `buttons: [{text, primary, onClick, keepOpen}]`).
public struct OrDialogButton: Identifiable {
    public let id = UUID()
    public var text: String
    public var primary: Bool
    public var keepOpen: Bool
    /// Return `false` to keep the dialog open (JS `onClick` returning `false`).
    public var action: (() -> Bool)?

    public init(_ text: String,
                primary: Bool = false,
                keepOpen: Bool = false,
                action: (() -> Bool)? = nil) {
        self.text = text
        self.primary = primary
        self.keepOpen = keepOpen
        self.action = action
    }
}

/// A Material dialog description. `content` is type-erased so the center can own the stack.
public struct OrDialogSpec: Identifiable {
    public let id = UUID()
    public var title: String?
    public var icon: String?
    public var content: AnyView?
    public var buttons: [OrDialogButton]
    public var cancelable: Bool
    public var width: CGFloat?
    /// `.m-dialog-actions { padding: 8px }`; project dialogs override the top to 20 dp
    /// (`.projects-dialog .m-dialog-actions { padding-top: 20px }`).
    public var actionsTopPadding: CGFloat
    public var onClose: (() -> Void)?

    public init(title: String? = nil,
                icon: String? = nil,
                content: AnyView? = nil,
                buttons: [OrDialogButton] = [],
                cancelable: Bool = true,
                width: CGFloat? = nil,
                actionsTopPadding: CGFloat = 8,
                onClose: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.content = content
        self.buttons = buttons
        self.cancelable = cancelable
        self.width = width
        self.actionsTopPadding = actionsTopPadding
        self.onClose = onClose
    }
}

/// Radio/check row used by the AlertDialog single-choice list (`ui-choice-row`).
public struct OrChoiceItem: Identifiable {
    public let id = UUID()
    public var label: String
    public var icon: String?

    public init(label: String, icon: String? = nil) {
        self.label = label
        self.icon = icon
    }
}

// MARK: - Center

/// Owns the dialog stack (Android dialogs are modal and stack up; the JS port appends scrims).
@MainActor
public final class DialogCenter: ObservableObject {
    @Published public private(set) var stack: [OrDialogSpec] = []

    public init() {}

    public var isPresented: Bool { !stack.isEmpty }
    public var top: OrDialogSpec? { stack.last }

    public func show(_ spec: OrDialogSpec) {
        stack.append(spec)
    }

    @discardableResult
    public func closeTop() -> Bool {
        guard let spec = stack.popLast() else { return false }
        spec.onClose?()
        return true
    }

    public func closeAll() {
        while !stack.isEmpty { closeTop() }
    }

    // MARK: Convenience constructors (mirror the JS helpers)

    /// `M.confirm(title, text, positiveText, negativeText, cb)`.
    @discardableResult
    public func confirm(title: String,
                        text: String,
                        positiveText: String = "OK",
                        negativeText: String = "Cancel",
                        icon: String? = nil,
                        width: CGFloat? = 280,
                        actionsTopPadding: CGFloat = 20,
                        onResult: ((Bool) -> Void)? = nil) -> OrDialogSpec {
        let spec = OrDialogSpec(
            title: title,
            icon: icon,
            content: AnyView(OrDialogText(text)),
            buttons: [
                OrDialogButton(negativeText) { onResult?(false); return true },
                OrDialogButton(positiveText, primary: true) { onResult?(true); return true },
            ],
            width: width,
            actionsTopPadding: actionsTopPadding
        )
        show(spec)
        return spec
    }

    /// Generic alert with an OK button (`D.error.show` / feature-unavailable dialogs).
    @discardableResult
    public func alert(title: String,
                      message: String? = nil,
                      icon: String? = nil,
                      positiveText: String = "OK",
                      width: CGFloat? = 280) -> OrDialogSpec {
        let spec = OrDialogSpec(
            title: title,
            icon: icon,
            content: message.map { AnyView(OrDialogText($0)) },
            buttons: [OrDialogButton(positiveText, primary: true)],
            width: width,
            actionsTopPadding: 20
        )
        show(spec)
        return spec
    }

    /// Android `ErrorDialogFragment`: title "Attention", error_outline icon, OK.
    @discardableResult
    public func showError(_ message: String) -> OrDialogSpec {
        alert(title: CommonDialogStrings.attention,
              message: String(describing: message),
              icon: "ic_error_outline_dark_24dp",
              positiveText: CommonDialogStrings.ok)
    }

    /// Material text input dialog (`M.textDialog`). `onResult(nil)` on cancel.
    @discardableResult
    public func textDialog(title: String,
                           icon: String? = nil,
                           initialValue: String = "",
                           hint: String? = nil,
                           sanitize: ((String) -> String)? = nil,
                           positiveText: String = "OK",
                           negativeText: String = "Cancel",
                           width: CGFloat? = 280,
                           actionsTopPadding: CGFloat = 8,
                           contentTopPadding: CGFloat = 0,
                           onResult: @escaping (String?) -> Void) -> OrTextInputModel {
        let model = OrTextInputModel(text: initialValue, hint: hint, sanitize: sanitize)
        model.onSubmit = { [weak self] in
            guard let self else { return }
            onResult(model.text)
            self.closeTop()
        }
        let spec = OrDialogSpec(
            title: title,
            icon: icon,
            content: AnyView(OrTextInputField(model: model)
                .padding(.top, contentTopPadding)),
            buttons: [
                OrDialogButton(negativeText) { onResult(nil); return true },
                OrDialogButton(positiveText, primary: true) {
                    onResult(model.text)
                    return true
                },
            ],
            width: width,
            actionsTopPadding: actionsTopPadding
        )
        show(spec)
        return model
    }

    /// Material number picker dialog: − value + plus the optional x1/2 / x2 buttons.
    @discardableResult
    public func numberDialog(title: String,
                             label: String? = nil,
                             value: Int,
                             minValue: Int,
                             maxValue: Int,
                             halfLabel: String? = nil,
                             twiceLabel: String? = nil,
                             positiveText: String = "OK",
                             negativeText: String = "Cancel",
                             onResult: @escaping (Int?) -> Void) -> OrNumberPickerModel {
        let model = OrNumberPickerModel(value: value, minValue: minValue, maxValue: maxValue)
        let spec = OrDialogSpec(
            title: title,
            content: AnyView(OrNumberPickerDialogContent(model: model,
                                                         label: label,
                                                         halfLabel: halfLabel,
                                                         twiceLabel: twiceLabel)),
            buttons: [
                OrDialogButton(negativeText) { onResult(nil); return true },
                OrDialogButton(positiveText, primary: true) {
                    onResult(model.value)
                    return true
                },
            ],
            width: 360
        )
        show(spec)
        return model
    }

    /// AlertDialog.setSingleChoiceItems replacement (radio rows, closes on select).
    @discardableResult
    public func singleChoice(title: String,
                             icon: String? = nil,
                             items: [OrChoiceItem],
                             selectedIndex: Int = 0,
                             onSelect: @escaping (Int) -> Void) -> OrDialogSpec {
        let choices = OrChoiceList(items: items, selectedIndex: selectedIndex) { index in
            onSelect(index)
        }
        let spec = OrDialogSpec(
            title: title,
            icon: icon,
            content: AnyView(choices),
            buttons: [],
            cancelable: true,
            // AlertDialog.setSingleChoiceItems: wrap-content list dialog (min 280 dp).
            width: 280
        )
        show(spec)
        return spec
    }
}

// MARK: - Host

/// Root overlay that renders the topmost dialog over a scrim.
public struct OrDialogHost: View {
    @ObservedObject public var center: DialogCenter

    public init(center: DialogCenter) {
        self.center = center
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let spec = center.top {
                    OrDialogScrim(spec: spec,
                                  center: center,
                                  containerSize: proxy.size)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.12), value: center.stack.count)
    }
}

private struct OrDialogScrim: View {
    var spec: OrDialogSpec
    @ObservedObject var center: DialogCenter
    var containerSize: CGSize

    @Environment(\.oripaSnapshotMode) private var snapshotMode
    @State private var appeared = false

    var body: some View {
        ZStack {
            OrTheme.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if spec.cancelable { center.closeTop() }
                }
            OrDialogCard(spec: spec, center: center, containerSize: containerSize)
                .scaleEffect((appeared || snapshotMode) ? 1 : 0.92)
                .opacity((appeared || snapshotMode) ? 1 : 0.4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.14)) { appeared = true }
        }
    }
}

private struct OrDialogCard: View {
    var spec: OrDialogSpec
    @ObservedObject var center: DialogCenter
    var containerSize: CGSize

    @Environment(\.oripaSnapshotMode) private var snapshotMode

    private var computedWidth: CGFloat {
        // AppCompat AlertDialog measures 87 % of the phone width (357.7 dp on the APK's
        // 411.4 dp window); tablet/iPad clamps to the 560 dp material maximum.
        let available = max(280, containerSize.width - OrTheme.dialogPadding * 2)
        let preferred = spec.width ?? 358
        return min(min(preferred, 560), available)
    }

    private var maxContentHeight: CGFloat {
        max(80, containerSize.height * 0.6)
    }

    /// Natural height of the dialog body, measured so the card hugs short content instead of
    /// always filling half the screen (the JS dialog sizes to content and scrolls beyond).
    @State private var measuredContentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if spec.title != nil || spec.icon != nil {
                HStack(spacing: 8) {
                    if let icon = spec.icon {
                        // abc_alert_dialog_title_material: 32 dp icon + 8 dp title margin.
                        MaterialIcon(icon, size: 32, tint: OrTheme.iconActive)
                    }
                    if let title = spec.title {
                        Text(title)
                            .font(OrTheme.dialogTitle())
                            .foregroundColor(OrTheme.textPrimary)
                            // `.m-dialog-title { font-size: 20px; line-height: 28px }`
                            .orLineHeight(28, fontSize: 20)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
            }
            if let content = spec.content {
                if snapshotMode {
                    // ImageRenderer cannot rasterise ScrollView content; render eagerly.
                    content
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                } else {
                    ScrollView(.vertical, showsIndicators: measuredContentHeight > maxContentHeight) {
                        content
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(key: OrDialogContentHeightKey.self,
                                                           value: proxy.size.height)
                                }
                            )
                    }
                    .frame(height: min(max(measuredContentHeight, 1), maxContentHeight))
                    .onPreferenceChange(OrDialogContentHeightKey.self) { measuredContentHeight = $0 }
                }
            }
            if !spec.buttons.isEmpty {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    ForEach(spec.buttons) { button in
                        OrTextButton(button.text, isPrimary: button.primary) {
                            let keep: Bool
                            if let action = button.action {
                                keep = action() == false
                            } else {
                                keep = false
                            }
                            if !keep && !button.keepOpen {
                                center.closeTop()
                            }
                        }
                    }
                }
                // abc_alert_dialog_button_bar_material: 12 dp horizontal / 4 dp vertical
                // padding, 62 dp total bar height (54 dp buttons).
                .padding(.horizontal, 12)
                .padding(.top, spec.actionsTopPadding)
                .padding(.bottom, 4)
                .frame(minHeight: 54)
            }
        }
        .frame(width: computedWidth, alignment: .leading)
        .padding(.bottom, spec.buttons.isEmpty ? 8 : 0)
        .background(OrTheme.dialogBackground)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .compositingGroup()
        .orElevation(24)
    }
}

// MARK: - Dialog content building blocks

/// Plain dialog body text (`<p class="m-dialog-text">`).
public struct OrDialogText: View {
    public var text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(OrTheme.dialogText())
            .foregroundColor(OrTheme.textSecondary)
            // `.m-dialog-content { font-size: 16px; line-height: 24px }`
            .orLineHeight(24, fontSize: 16)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Shared state of a text input dialog.
@MainActor
public final class OrTextInputModel: ObservableObject {
    @Published public var text: String
    public var hint: String?
    public var sanitize: ((String) -> String)?
    /// Invoked when the user presses Return (`input.addEventListener("keydown", …Enter…)`).
    public var onSubmit: (() -> Void)?

    public init(text: String = "", hint: String? = nil, sanitize: ((String) -> String)? = nil) {
        self.text = text
        self.hint = hint
        self.sanitize = sanitize
    }
}

/// Material underlined text field used inside dialogs.
public struct OrTextInputField: View {
    @ObservedObject var model: OrTextInputModel
    @FocusState private var focused: Bool
    @Environment(\.oripaSnapshotMode) private var snapshotMode

    public init(model: OrTextInputModel) {
        self.model = model
    }

    public var body: some View {
        if snapshotMode {
            // ImageRenderer cannot rasterise the AppKit/UIKit-backed TextField; draw the
            // editable line statically for visual QA (runtime always uses the TextField).
            // The dialogs select-all on focus (dialog_edittext.xml), which the reference
            // screenshots show as the platform selection highlight behind the value.
            let hasSelection = !model.text.isEmpty
            VStack(alignment: .leading, spacing: 0) {
                Text(model.text.isEmpty ? (model.hint ?? "") : model.text)
                    .font(.system(size: 16))
                    .foregroundColor(model.text.isEmpty ? OrTheme.textDisabled : OrTheme.textPrimary)
                    .padding(.horizontal, 1)
                    .background(hasSelection ? Color(hex: 0xB3D7FE) : Color.clear)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                Rectangle()
                    .fill(OrTheme.accent)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        } else {
            textField
        }
    }

    private var textField: some View {
        TextField(model.hint ?? "", text: Binding(
            get: { model.text },
            set: { newValue in
                if let sanitize = model.sanitize {
                    model.text = sanitize(newValue)
                } else {
                    model.text = newValue
                }
            }
        ))
        .textFieldStyle(.plain)
        .font(.system(size: 16))
        .foregroundColor(OrTheme.textPrimary)
        .autocorrectionDisabled(true)
        #if os(iOS)
        .textInputAutocapitalization(.never)
        #endif
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(focused ? OrTheme.accent : OrTheme.divider)
                .frame(height: 2)
        }
        .focused($focused)
        .onSubmit { model.onSubmit?() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { focused = true }
        }
        .frame(maxWidth: .infinity)
    }
}

/// AlertDialog single-choice radio list.
struct OrChoiceList: View {
    var items: [OrChoiceItem]
    @State var selectedIndex: Int
    var onSelect: (Int) -> Void
    @EnvironmentObject private var dialogs: DialogCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    selectedIndex = index
                    dialogs.closeTop()
                    onSelect(index)
                } label: {
                    HStack(spacing: 16) {
                        if let icon = item.icon {
                            MaterialIcon(icon, size: 24, tint: OrTheme.iconActive)
                        }
                        Text(item.label)
                            .font(.system(size: 16))
                            .foregroundColor(OrTheme.textPrimary)
                        Spacer(minLength: 0)
                        OrRadioMark(isChecked: index == selectedIndex)
                    }
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Material radio mark (outer ring + inner dot when checked).
public struct OrRadioMark: View {
    public var isChecked: Bool
    public init(isChecked: Bool) { self.isChecked = isChecked }
    public var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isChecked ? OrTheme.accent : OrTheme.iconActive, lineWidth: 2)
                .frame(width: 20, height: 20)
            if isChecked {
                Circle()
                    .fill(OrTheme.accent)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - Shared dialog strings (android.R.string.*)

/// android.R.string values used by AlertDialogs across the port.
public enum CommonDialogStrings {
    /// android.R.string.dialog_alert_title — ErrorDialogFragment title.
    public static let attention = "Attention"
    /// android.R.string.ok.
    public static let ok = "OK"
    /// android.R.string.cancel.
    public static let cancel = "Cancel"
}

// MARK: - Content height measurement

private struct OrDialogContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
