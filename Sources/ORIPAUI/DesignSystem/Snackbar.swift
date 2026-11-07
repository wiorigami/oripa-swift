// Material snackbar queue + root-level host.
//
// Port of `M.snackbar` / `showNextSnack` from `src/js/ui/components/material.js`:
// one snackbar at a time, dark #323232 surface, white 14 sp text, optional uppercase
// accent action, 3200 ms default duration, queued when several are posted together.
import SwiftUI

/// One queued snackbar message.
public struct SnackbarItem: Identifiable, Equatable {
    public let id = UUID()
    public var text: String
    public var actionText: String?
    public var duration: TimeInterval
    public var onAction: (() -> Void)?

    public init(text: String,
                actionText: String? = nil,
                duration: TimeInterval = OrTheme.snackbarDuration,
                onAction: (() -> Void)? = nil) {
        self.text = text
        self.actionText = actionText
        self.duration = duration
        self.onAction = onAction
    }

    public static func == (lhs: SnackbarItem, rhs: SnackbarItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Owns the snackbar queue and the currently visible snackbar.
@MainActor
public final class SnackbarCenter: ObservableObject {
    @Published public private(set) var current: SnackbarItem?
    private var queue: [SnackbarItem] = []

    public init() {}

    /// `M.snackbar(text, {actionText, onAction, duration})`.
    public func show(_ text: String,
                     actionText: String? = nil,
                     duration: TimeInterval = OrTheme.snackbarDuration,
                     onAction: (() -> Void)? = nil) {
        let item = SnackbarItem(text: text,
                                actionText: actionText,
                                duration: duration,
                                onAction: onAction)
        if current == nil {
            current = item
        } else {
            queue.append(item)
        }
    }

    /// Called by the host when the current snackbar's timer fires or its action is tapped.
    public func dismissCurrent() {
        guard current != nil else { return }
        current = queue.isEmpty ? nil : queue.removeFirst()
    }

    /// Called by the action button; runs the callback then dismisses.
    public func performAction() {
        let item = current
        dismissCurrent()
        item?.onAction?()
    }

    public func dismissAll() {
        queue.removeAll()
        current = nil
    }
}

/// Root overlay host for the current snackbar (bottom centre, Material elevation 8).
public struct SnackbarHost: View {
    @ObservedObject public var center: SnackbarCenter

    public init(center: SnackbarCenter) {
        self.center = center
    }

    public var body: some View {
        VStack {
            Spacer(minLength: 0)
            if let item = center.current {
                SnackbarView(item: item, center: center)
                    .id(item.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.16), value: center.current?.id)
        .allowsHitTesting(center.current != nil)
    }
}

private struct SnackbarView: View {
    let item: SnackbarItem
    @ObservedObject var center: SnackbarCenter

    var body: some View {
        HStack(spacing: 16) {
            Text(item.text)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionText = item.actionText {
                Button {
                    center.performAction()
                } label: {
                    Text(actionText.uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .kerning(1.0)
                        .foregroundColor(OrTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minWidth: OrTheme.snackbarMinWidth, maxWidth: 560, alignment: .leading)
        .background(OrTheme.snackbarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .orElevation(8)
        .task(id: item.id) {
            let nanoseconds = UInt64(max(0, item.duration) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            if !Task.isCancelled {
                center.dismissCurrent()
            }
        }
    }
}
