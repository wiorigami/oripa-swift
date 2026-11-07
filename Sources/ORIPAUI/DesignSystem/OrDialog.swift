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
    public var onClose: (() -> Void)?

    public init(title: String? = nil,
                icon: String? = nil,
                content: AnyView? = nil,
                buttons: [OrDialogButton] = [],
                cancelable: Bool = true,
                width: CGFloat? = nil,
                onClose: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.content = content
        self.buttons = buttons
        self.cancelable = cancelable
        self.width = width
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
                        onResult: ((Bool) -> Void)? = nil) -> OrDialogSpec {
        let spec = OrDialogSpec(
            title: title,
            icon: icon,
            content: AnyView(OrDialogText(text)),
            buttons: [
                OrDialogButton(negativeText) { onResult?(false); return true },
                OrDialogButton(positiveText, primary: true) { onResult?(true); return true },
            ]
        )
        show(spec)
        return spec
    }

    /// Generic alert with an OK button (`D.error.show` / feature-unavailable dialogs).
    @discardableResult
    public func alert(title: String,
                      message: String? = nil,
                      icon: String? = nil,
                      positiveText: String = "OK") -> OrDialogSpec {
        let spec = OrDialogSpec(
            title: title,
            icon: icon,
            content: message.map { AnyView(OrDialogText($0)) },
            buttons: [OrDialogButton(positiveText, primary: true)]
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
                           onResult: @escaping (String?) -> Void) -> OrTextInputModel {
        let model = OrTextInputModel(text: initialValue, hint: hint, sanitize: sanitize)
        let spec = OrDialogSpec(
            title: title,
            icon: icon,
            content: AnyView(OrTextInputField(model: model)),
            buttons: [
                OrDialogButton(negativeText) { onResult(nil); return true },
                OrDialogButton(positiveText, primary: true) {
                    onResult(model.text)
                    return true
                },
            ]
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
            cancelable: true
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
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0.4)
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

    private var computedWidth: CGFloat {
        let available = max(280, containerSize.width - OrTheme.dialogPadding * 2)
        let preferred = spec.width ?? 560
        return min(min(preferred, 560), available)
    }

    private var maxContentHeight: CGFloat {
        max(80, containerSize.height * 0.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if spec.title != nil || spec.icon != nil {
                HStack(spacing: 16) {
                    if let icon = spec.icon {
                        MaterialIcon(icon, size: 24, tint: OrTheme.iconActive)
                    }
                    if let title = spec.title {
                        Text(title)
                            .font(OrTheme.dialogTitle())
                            .foregroundColor(OrTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            if let content = spec.content {
                ScrollView(.vertical, showsIndicators: true) {
                    content
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
                .frame(maxHeight: maxContentHeight)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(minHeight: OrTheme.dialogActionsHeight)
            }
        }
        .frame(width: computedWidth, alignment: .leading)
        .padding(.bottom, spec.buttons.isEmpty ? 8 : 0)
        .background(OrTheme.dialogBackground)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .orElevation(24)
        .frame(maxHeight: containerSize.height * 0.9)
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

    public init(model: OrTextInputModel) {
        self.model = model
    }

    public var body: some View {
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
