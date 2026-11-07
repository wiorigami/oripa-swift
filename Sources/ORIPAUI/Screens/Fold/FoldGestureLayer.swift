// Multi-touch / pointer gesture surface for the fold screen — port of the touch handling in
// Android `AbstractGLSurfaceView` / `AbstractDoubleGLSurfaceView` / `GLSurfaceViewFoldCpCross`
// (via the web port's `ORIPA.ui.GestureRecognizer` + `fold.js` gestureHandlers):
//
//   * two-finger pinch / pan / rotate (all x-ray/overlap; per panel in the Cut Line view),
//   * one-finger drag (Cut Line: move/rotate the cut line when starting in the FM panel),
//   * no tap / long-press actions (Java onSingleTapUp/onLongPress are no-ops).
//
// SwiftUI has no two-finger pan/rotate gesture, so this is a thin transparent touch surface
// behind the chrome: a UIView with raw touch tracking on iOS and an NSView consuming
// scrollWheel / magnify / rotate events on macOS (trackpad). All platform code lives in this
// file; the shared `FoldGestureHandlers` closure bundle keeps the drawing cross-platform.
import SwiftUI

// MARK: - Shared gesture payload

/// Two-finger pair state since the gesture start (JS `{cx, cy, scale, rotation}`).
struct FoldTwoFingerState {
    /// Current centroid (canvas points).
    var center: CGPoint
    /// Cumulative scale since the gesture start (`dist / startDist`).
    var scale: CGFloat
    /// Cumulative rotation since the gesture start in radians (`angle - startAngle`).
    var rotationRadians: CGFloat
}

/// Gesture callbacks consumed by `FoldViewModel` (the fold.js `gestureHandlers` object).
struct FoldGestureHandlers {
    var onTwoFingerStart: (CGPoint) -> Void = { _ in }
    var onTwoFingerMove: (FoldTwoFingerState) -> Void = { _ in }
    var onTwoFingerEnd: () -> Void = {}
    var onDragStart: (CGPoint) -> Void = { _ in }
    var onDrag: (CGPoint) -> Void = { _ in }
    var onDragEnd: () -> Void = {}
    var onCancel: () -> Void = {}
}

/// Transparent full-area gesture surface (placed above the canvas, below the chrome).
struct FoldGestureLayer: View {
    let handlers: FoldGestureHandlers

    var body: some View {
        #if canImport(UIKit)
        FoldUIKitGestureView(handlers: handlers)
        #elseif canImport(AppKit)
        FoldMacGestureView(handlers: handlers)
        #else
        Color.clear
        #endif
    }
}

// MARK: - iOS / iPadOS touch surface

#if canImport(UIKit)
import UIKit

private final class FoldTouchView: UIView {
    var handlers = FoldGestureHandlers()

    private var positions: [ObjectIdentifier: CGPoint] = [:]
    private var twoFingerStart: (distance: CGFloat, angle: CGFloat, center: CGPoint)?
    private var oneFingerStart: CGPoint?
    private var dragging = false
    private var multi = false

    /// `GestureRecognizer` TAP_SLOP: a one-finger drag starts after 14 px.
    private static let tapSlop: CGFloat = 14

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isOpaque = false
    }

    // MARK: Touch tracking

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            positions[ObjectIdentifier(touch)] = touch.location(in: self)
        }
        if positions.count >= 2 {
            multi = true
            dragging = false
            oneFingerStart = nil
            guard let pair = pairState() else { return }
            twoFingerStart = pair
            handlers.onTwoFingerStart(pair.center)
        } else if positions.count == 1, let point = positions.values.first {
            oneFingerStart = point
            dragging = false
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            positions[ObjectIdentifier(touch)] = touch.location(in: self)
        }
        if multi, positions.count >= 2, let start = twoFingerStart {
            guard let pair = pairState() else { return }
            let scale = start.distance > 0 ? pair.distance / start.distance : 1
            handlers.onTwoFingerMove(FoldTwoFingerState(center: pair.center,
                                                        scale: scale,
                                                        rotationRadians: pair.angle - start.angle))
            return
        }
        guard positions.count == 1, let point = positions.values.first else { return }
        guard let start = oneFingerStart else { return }
        if !dragging {
            let moved = (point.x - start.x) * (point.x - start.x) + (point.y - start.y) * (point.y - start.y)
            if moved > Self.tapSlop * Self.tapSlop {
                dragging = true
                handlers.onDragStart(start)
            }
        }
        if dragging { handlers.onDrag(point) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            positions.removeValue(forKey: ObjectIdentifier(touch))
        }
        if multi {
            if positions.count < 2 {
                multi = false
                twoFingerStart = nil
                handlers.onTwoFingerEnd()
                if positions.count == 1, let point = positions.values.first {
                    // A remaining finger can start a one-finger Cut Line drag.
                    oneFingerStart = point
                    dragging = false
                }
            }
        } else if dragging {
            dragging = false
            handlers.onDragEnd()
            oneFingerStart = nil
        } else {
            // Tap: no tap actions in the fold views (Java onSingleTapUp is a no-op).
            oneFingerStart = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetTouches()
        handlers.onCancel()
    }

    private func resetTouches() {
        positions.removeAll()
        twoFingerStart = nil
        oneFingerStart = nil
        dragging = false
        multi = false
    }

    /// `pairState()` of the web GestureRecognizer: distance / angle / centroid of two touches.
    private func pairState() -> (distance: CGFloat, angle: CGFloat, center: CGPoint)? {
        let points = Array(positions.values)
        guard points.count >= 2 else { return nil }
        let a = points[0]
        let b = points[1]
        let distance = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
        let angle = atan2(b.y - a.y, b.x - a.x)
        return (distance, angle, CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
    }
}

private struct FoldUIKitGestureView: UIViewRepresentable {
    let handlers: FoldGestureHandlers

    func makeUIView(context: Context) -> FoldTouchView {
        let view = FoldTouchView()
        view.handlers = handlers
        return view
    }

    func updateUIView(_ uiView: FoldTouchView, context: Context) {
        uiView.handlers = handlers
    }
}
#endif

// MARK: - macOS trackpad surface

#if canImport(AppKit)
import AppKit

private final class FoldMacGestureSurface: NSView {
    var handlers = FoldGestureHandlers()

    private var dragStart: CGPoint?
    private var dragging = false
    private var twoFingerActive = false
    private var twoFingerScale: CGFloat = 1
    private var twoFingerRotation: CGFloat = 0
    private var twoFingerCenter: CGPoint = .zero
    private var lastTwoFingerEvent: TimeInterval = 0

    private static let tapSlop: CGFloat = 14
    /// A new pinch/scroll sequence starts after a short idle gap (AppKit gives no pointer ids).
    private static let sequenceGap: TimeInterval = 0.3

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: One-finger (mouse / trackpad click-drag)

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStart = point
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        if !dragging {
            let moved = (point.x - start.x) * (point.x - start.x) + (point.y - start.y) * (point.y - start.y)
            if moved > Self.tapSlop * Self.tapSlop {
                dragging = true
                handlers.onDragStart(start)
            }
        }
        if dragging { handlers.onDrag(point) }
    }

    override func mouseUp(with event: NSEvent) {
        if dragging { handlers.onDragEnd() }
        dragging = false
        dragStart = nil
    }

    // MARK: Two-finger trackpad gestures

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        beginTwoFingerIfNeeded(center: point)
        twoFingerCenter = CGPoint(x: twoFingerCenter.x + event.scrollingDeltaX,
                                  y: twoFingerCenter.y + event.scrollingDeltaY)
        emitTwoFingerMove()
        if event.phase == .ended || event.phase == .cancelled { endTwoFinger() }
    }

    override func magnify(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        beginTwoFingerIfNeeded(center: point)
        twoFingerScale *= (1.0 + event.magnification)
        emitTwoFingerMove()
        if event.phase == .ended || event.phase == .cancelled { endTwoFinger() }
    }

    override func rotate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        beginTwoFingerIfNeeded(center: point)
        // AppKit reports counter-clockwise degrees; the camera wants clockwise-positive.
        twoFingerRotation += CGFloat(-event.rotation) * CGFloat.pi / 180.0
        emitTwoFingerMove()
        if event.phase == .ended || event.phase == .cancelled { endTwoFinger() }
    }

    private func beginTwoFingerIfNeeded(center: CGPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        if !twoFingerActive || now - lastTwoFingerEvent > Self.sequenceGap {
            if twoFingerActive { handlers.onTwoFingerEnd() }
            twoFingerActive = true
            twoFingerScale = 1
            twoFingerRotation = 0
            twoFingerCenter = center
            handlers.onTwoFingerStart(center)
        }
        lastTwoFingerEvent = now
    }

    private func emitTwoFingerMove() {
        guard twoFingerActive else { return }
        handlers.onTwoFingerMove(FoldTwoFingerState(center: twoFingerCenter,
                                                    scale: twoFingerScale,
                                                    rotationRadians: twoFingerRotation))
    }

    private func endTwoFinger() {
        guard twoFingerActive else { return }
        twoFingerActive = false
        handlers.onTwoFingerEnd()
    }
}

private struct FoldMacGestureView: NSViewRepresentable {
    let handlers: FoldGestureHandlers

    func makeNSView(context: Context) -> FoldMacGestureSurface {
        let view = FoldMacGestureSurface()
        view.handlers = handlers
        return view
    }

    func updateNSView(_ nsView: FoldMacGestureSurface, context: Context) {
        nsView.handlers = handlers
    }
}
#endif
