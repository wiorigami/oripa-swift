// Multi-touch gesture recognition for the crease-pattern canvases.
//
// Port of `oripa-port/src/js/ui/components/gestures.js` (itself a port of the touch
// handling in the Android GLSurfaceView subclasses) to native Apple input:
//
//   iOS / iPadOS : raw `UIView` touches (multi-touch, Apple Pencil and pointer friendly —
//                  all arrive as touches), exactly like Android's onTouchEvent stream.
//   macOS        : `NSView` mouse events (click / drag / press-and-hold) plus trackpad
//                  `scrollWheel` (two-finger pan) and `magnify` (pinch).
//
// The shared `CanvasGestureRecognizer` implements the gesture state machine:
//   tap (deferred by the 260 ms double-tap window, like GestureDetector
//   .onSingleTapConfirmed), double tap, long press (480 ms), one-finger drag
//   (selection rectangle), two-finger pinch + pan.
//
// All coordinates are canvas CSS px (SwiftUI points) relative to the canvas element.
// Main-thread only.
import CoreGraphics
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Two-finger state (port of gestures.js `state`)

public struct TwoFingerState: Equatable {
    public var cx: CGFloat = 0
    public var cy: CGFloat = 0
    public var panX: CGFloat = 0
    public var panY: CGFloat = 0
    public var scale: CGFloat = 1
    public var rotation: CGFloat = 0

    public init(cx: CGFloat = 0, cy: CGFloat = 0, panX: CGFloat = 0, panY: CGFloat = 0,
                scale: CGFloat = 1, rotation: CGFloat = 0) {
        self.cx = cx
        self.cy = cy
        self.panX = panX
        self.panY = panY
        self.scale = scale
        self.rotation = rotation
    }
}

// MARK: - Recogniser

/// Port of `ORIPA.ui.GestureRecognizer`. Platform views feed pointer events into
/// `pointerDown/Move/Up/Cancel`; the recogniser turns them into the callback sequence.
public final class CanvasGestureRecognizer {
    public struct Callbacks {
        public var onDown: ((CGFloat, CGFloat) -> Void)?
        /// Raw pointer-up with no movement (Android `onSingleTapUp`): the paint fragment shows
        /// the touch circle here immediately, before the deferred single-tap is confirmed.
        public var onSingleTapUp: ((CGFloat, CGFloat) -> Void)?
        public var onTap: ((CGFloat, CGFloat) -> Void)?
        public var onDoubleTap: ((CGFloat, CGFloat) -> Void)?
        /// Long press delivers the *start* point, like the JS implementation.
        public var onLongPress: ((CGFloat, CGFloat) -> Void)?
        public var onDragStart: ((CGFloat, CGFloat) -> Void)?
        /// (x, y, dx, dy)
        public var onDrag: ((CGFloat, CGFloat, CGFloat, CGFloat) -> Void)?
        public var onDragEnd: ((CGFloat, CGFloat) -> Void)?
        public var onTwoFingerStart: ((TwoFingerState) -> Void)?
        public var onTwoFingerMove: ((TwoFingerState) -> Void)?
        public var onTwoFingerEnd: (() -> Void)?
        public var onCancel: (() -> Void)?

        public init() {}
    }

    public var callbacks: Callbacks

    public var enabled: Bool = true {
        didSet { if !enabled { cancelAll() } }
    }

    public private(set) var pointerCount: Int = 0

    // Tuning constants (gestures.js).
    private let tapSlop: CGFloat = 14
    private let doubleTapMS: TimeInterval = 0.260
    private let longPressMS: TimeInterval = 0.480

    private struct Pointer {
        var x: CGFloat
        var y: CGFloat
        var startX: CGFloat
        var startY: CGFloat
    }

    private struct GestureStart {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var t: TimeInterval = 0
        var dist: CGFloat = 0
        var angle: CGFloat = 0
        var cx: CGFloat = 0
        var cy: CGFloat = 0
    }

    private var pointers: [Int: Pointer] = [:]
    private var active = false
    private var dragging = false
    private var multi = false
    private var longPressed = false
    private var start = GestureStart()
    private var last = CGPoint.zero
    private var lastTapTime: TimeInterval = 0
    private var lastTapX: CGFloat = 0
    private var lastTapY: CGFloat = 0
    private var pendingTap: CGPoint?
    private var tapWork: DispatchWorkItem?
    private var longPressWork: DispatchWorkItem?

    /// Synthetic two-finger state used by the macOS trackpad adapter.
    private var syntheticTwo: TwoFingerState?

    public init(callbacks: Callbacks = Callbacks()) {
        self.callbacks = callbacks
    }

    private func now() -> TimeInterval { Date.timeIntervalSinceReferenceDate }

    // MARK: Pointer plumbing

    public func pointerDown(id: Int = 0, x: CGFloat, y: CGFloat) {
        guard enabled else { return }
        pointers[id] = Pointer(x: x, y: y, startX: x, startY: y)
        pointerCount = pointers.count
        if pointers.count == 1 {
            active = true
            dragging = false
            multi = false
            longPressed = false
            start = GestureStart(x: x, y: y, t: now())
            last = CGPoint(x: x, y: y)
            callbacks.onDown?(x, y)
            clearLongPress()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.longPressWork = nil
                guard self.active, self.pointers.count == 1, !self.dragging, !self.multi else { return }
                self.longPressed = true
                self.callbacks.onLongPress?(self.start.x, self.start.y)
            }
            longPressWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + longPressMS, execute: work)
        } else if pointers.count == 2 {
            clearLongPress()
            multi = true
            dragging = false
            if let ps = pairState() {
                start = GestureStart(x: ps.cx, y: ps.cy, dist: ps.dist, angle: ps.angle, cx: ps.cx, cy: ps.cy)
                last = CGPoint(x: ps.cx, y: ps.cy)
                callbacks.onTwoFingerStart?(TwoFingerState(cx: ps.cx, cy: ps.cy))
            }
        }
    }

    public func pointerMove(id: Int = 0, x: CGFloat, y: CGFloat) {
        guard enabled, var p = pointers[id] else { return }
        p.x = x
        p.y = y
        pointers[id] = p

        if multi, pointers.count >= 2 {
            guard let ps = pairState() else { return }
            let st = TwoFingerState(cx: ps.cx, cy: ps.cy,
                                    panX: ps.cx - start.cx, panY: ps.cy - start.cy,
                                    scale: start.dist > 0 ? ps.dist / start.dist : 1,
                                    rotation: ps.angle - start.angle)
            last = CGPoint(x: ps.cx, y: ps.cy)
            callbacks.onTwoFingerMove?(st)
            return
        }

        let dx = x - last.x
        let dy = y - last.y
        last = CGPoint(x: x, y: y)
        let moved = hypot(x - start.x, y - start.y)
        if !dragging, moved > tapSlop {
            dragging = true
            clearLongPress()
            callbacks.onDragStart?(start.x, start.y)
        }
        if dragging {
            callbacks.onDrag?(x, y, dx, dy)
        }
    }

    public func pointerUp(id: Int = 0, x: CGFloat, y: CGFloat) {
        guard pointers.removeValue(forKey: id) != nil else { return }
        pointerCount = pointers.count
        clearLongPress()
        if multi {
            if pointers.count < 2 {
                multi = false
                callbacks.onTwoFingerEnd?()
            }
            if pointers.isEmpty {
                active = false
                dragging = false
            }
            return
        }
        if dragging {
            dragging = false
            active = false
            callbacks.onDragEnd?(x, y)
            return
        }
        active = false
        if longPressed {
            longPressed = false
            return
        }
        let moved = hypot(x - start.x, y - start.y)
        guard moved <= tapSlop else { return }
        callbacks.onSingleTapUp?(x, y)
        let t = now()
        if t - lastTapTime < doubleTapMS, hypot(x - lastTapX, y - lastTapY) < 24 {
            tapWork?.cancel()
            tapWork = nil
            pendingTap = nil
            lastTapTime = 0
            callbacks.onDoubleTap?(x, y)
        } else {
            flushPendingTap()
            lastTapTime = t
            lastTapX = x
            lastTapY = y
            scheduleTap(CGPoint(x: x, y: y))
        }
    }

    public func pointerCancel(id: Int = 0) {
        guard pointers.removeValue(forKey: id) != nil else { return }
        pointerCount = pointers.count
        if pointers.isEmpty {
            cancelAll()
        }
    }

    public func cancelAll() {
        clearLongPress()
        tapWork?.cancel()
        tapWork = nil
        pendingTap = nil
        pointers.removeAll()
        pointerCount = 0
        active = false
        dragging = false
        multi = false
        syntheticTwo = nil
        callbacks.onCancel?()
    }

    // MARK: Synthetic two-finger input (macOS trackpad)

    /// Start a trackpad two-finger stream at a canvas point.
    public func beginTwoFinger(cx: CGFloat, cy: CGFloat) {
        guard enabled else { return }
        clearLongPress()
        active = false
        dragging = false
        multi = true
        syntheticTwo = TwoFingerState(cx: cx, cy: cy)
        callbacks.onTwoFingerStart?(TwoFingerState(cx: cx, cy: cy))
    }

    /// Feed a two-finger update: cumulative scale factor and finger-pan deltas in px.
    public func updateTwoFinger(scaleFactor: CGFloat, panDX: CGFloat, panDY: CGFloat,
                                cx: CGFloat? = nil, cy: CGFloat? = nil) {
        guard enabled, var st = syntheticTwo else { return }
        st.cx = cx ?? (st.cx + panDX)
        st.cy = cy ?? (st.cy + panDY)
        st.scale *= scaleFactor
        st.panX += panDX
        st.panY += panDY
        syntheticTwo = st
        callbacks.onTwoFingerMove?(st)
    }

    public func endTwoFinger() {
        guard syntheticTwo != nil else { return }
        syntheticTwo = nil
        multi = false
        callbacks.onTwoFingerEnd?()
    }

    // MARK: Internal helpers

    private func pairState() -> (dist: CGFloat, angle: CGFloat, cx: CGFloat, cy: CGFloat)? {
        let ids = pointers.keys.sorted()
        guard ids.count >= 2, let a = pointers[ids[0]], let b = pointers[ids[1]] else { return nil }
        return (dist: hypot(b.x - a.x, b.y - a.y),
                angle: atan2(b.y - a.y, b.x - a.x),
                cx: (a.x + b.x) / 2,
                cy: (a.y + b.y) / 2)
    }

    private func clearLongPress() {
        longPressWork?.cancel()
        longPressWork = nil
    }

    private func deliverTap(_ p: CGPoint) {
        pendingTap = nil
        callbacks.onTap?(p.x, p.y)
    }

    private func flushPendingTap() {
        guard let p = pendingTap else { return }
        tapWork?.cancel()
        tapWork = nil
        deliverTap(p)
    }

    private func scheduleTap(_ p: CGPoint) {
        tapWork?.cancel()
        pendingTap = p
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.tapWork = nil
            if let pending = self.pendingTap { self.deliverTap(pending) }
        }
        tapWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapMS, execute: work)
    }

    public func destroy() {
        cancelAll()
        callbacks = Callbacks()
    }
}

// MARK: - SwiftUI overlay

/// Transparent input surface that installs the gesture recogniser over a `Canvas`.
/// Put it in a ZStack above the drawing canvas; it fills the available space.
public struct CanvasGestureOverlay: View {
    public let recognizer: CanvasGestureRecognizer

    public init(recognizer: CanvasGestureRecognizer) {
        self.recognizer = recognizer
    }

    public var body: some View {
        #if canImport(UIKit)
        iOSCanvasTouchView(recognizer: recognizer)
            .background(Color.clear)
        #elseif canImport(AppKit)
        macCanvasMouseView(recognizer: recognizer)
            .background(Color.clear)
        #else
        Color.clear
        #endif
    }
}

#if canImport(UIKit)

// MARK: - iOS raw touch surface

private struct iOSCanvasTouchView: UIViewRepresentable {
    let recognizer: CanvasGestureRecognizer

    func makeUIView(context: Context) -> TouchCaptureView {
        let view = TouchCaptureView()
        view.recognizer = recognizer
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isMultipleTouchEnabled = true
        view.isUserInteractionEnabled = true
        return view
    }

    func updateUIView(_ uiView: TouchCaptureView, context: Context) {
        uiView.recognizer = recognizer
    }

    final class TouchCaptureView: UIView {
        weak var recognizer: CanvasGestureRecognizer?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            for touch in touches {
                let p = touch.location(in: self)
                recognizer?.pointerDown(id: touch.hashValue, x: p.x, y: p.y)
            }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesMoved(touches, with: event)
            for touch in touches {
                let p = touch.location(in: self)
                recognizer?.pointerMove(id: touch.hashValue, x: p.x, y: p.y)
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            for touch in touches {
                let p = touch.location(in: self)
                recognizer?.pointerUp(id: touch.hashValue, x: p.x, y: p.y)
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            for touch in touches {
                recognizer?.pointerCancel(id: touch.hashValue)
            }
        }
    }
}

#elseif canImport(AppKit)

// MARK: - macOS mouse + trackpad surface

private struct macCanvasMouseView: NSViewRepresentable {
    let recognizer: CanvasGestureRecognizer

    func makeNSView(context: Context) -> MouseCaptureView {
        let view = MouseCaptureView()
        view.recognizer = recognizer
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: MouseCaptureView, context: Context) {
        nsView.recognizer = recognizer
    }

    final class MouseCaptureView: NSView {
        weak var recognizer: CanvasGestureRecognizer?
        private var mouseDownPoint: CGPoint?
        private var panActive = false

        /// SwiftUI uses a top-left origin; without this the pointer coordinates would be
        /// mirrored vertically (drawing/pinch focus offset).
        override var isFlipped: Bool { true }

        override var acceptsFirstResponder: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        private func local(_ event: NSEvent) -> CGPoint {
            convert(event.locationInWindow, from: nil)
        }

        override func mouseDown(with event: NSEvent) {
            let p = local(event)
            mouseDownPoint = p
            recognizer?.pointerDown(id: 0, x: p.x, y: p.y)
        }

        override func mouseDragged(with event: NSEvent) {
            let p = local(event)
            recognizer?.pointerMove(id: 0, x: p.x, y: p.y)
        }

        override func mouseUp(with event: NSEvent) {
            let p = local(event)
            mouseDownPoint = nil
            recognizer?.pointerUp(id: 0, x: p.x, y: p.y)
        }

        override func scrollWheel(with event: NSEvent) {
            guard let recognizer else { return }
            let p = local(event)
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            guard dx != 0 || dy != 0 else { return }
            if !panActive {
                panActive = true
                recognizer.beginTwoFinger(cx: p.x, cy: p.y)
            }
            // Native two-finger pan: moving the fingers moves the drawing (= -delta).
            recognizer.updateTwoFinger(scaleFactor: 1, panDX: -dx, panDY: -dy, cx: p.x, cy: p.y)
            schedulePanEnd()
        }

        private var panEndWork: DispatchWorkItem?

        private func schedulePanEnd() {
            panEndWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.panActive = false
                self.recognizer?.endTwoFinger()
            }
            panEndWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
        }

        override func magnify(with event: NSEvent) {
            guard let recognizer else { return }
            let p = local(event)
            if !panActive {
                panActive = true
                recognizer.beginTwoFinger(cx: p.x, cy: p.y)
            }
            recognizer.updateTwoFinger(scaleFactor: 1 + event.magnification, panDX: 0, panDY: 0,
                                       cx: p.x, cy: p.y)
            schedulePanEnd()
        }

        override func rightMouseDown(with event: NSEvent) { /* reserved */ }

        deinit {
            panEndWork?.cancel()
        }
    }
}

#endif
