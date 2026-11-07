// Port of `oripa-port/src/js/render/Camera.js`
// (equivalent of the transform matrix accumulated by AbstractGLSurfaceView / GLUtil,
// stored in readable form):
//
//   world(q)  = t + R(rotationDeg) * (scale * object)
//   screen    = panelCentre + k * world        (k = panelH / (2 * objectHalfSize))
//
// Object space = crease-pattern / folded-model coordinates. As in the Android GL
// renderer, object Y positive is DOWN on screen (the projection is y-flipped) and a
// positive rotation is clockwise on screen.
//
// The fold UI mutates the camera with zoomAt / panBy / rotateAt (canvas CSS px); the
// fold renderer assigns the viewport + panel rect on resize. This file is shared with
// the ui-fold workstream and therefore carries no ORIPACore dependency.
import CoreGraphics
import Foundation

public final class Camera {
    // MARK: - Constants (Constant.MIN_SCALE_FACTOR / MAX_SCALE_FACTOR)

    public static let MIN_SCALE_FACTOR: CGFloat = 0.20000000298023224
    public static let MAX_SCALE_FACTOR: CGFloat = 10000.0

    // MARK: - State

    /// == Android `mScaleFactor`; initial S(0.5).
    public var scale: CGFloat = 0.5
    /// World-space translation (world units).
    public var tx: CGFloat = 0.0
    public var ty: CGFloat = 0.0
    /// Rotation in degrees; positive = clockwise on screen.
    public var rotationDeg: CGFloat = 0.0

    public var viewportW: CGFloat
    public var viewportH: CGFloat
    public var objectHalfSize: CGFloat

    /// Panel rect (split "cross" view): defaults to the whole viewport.
    public var panelX: CGFloat = 0.0
    public var panelY: CGFloat = 0.0
    public var panelW: CGFloat
    public var panelH: CGFloat

    // MARK: - Init

    public init(viewportW: CGFloat = 0, viewportH: CGFloat = 0, objectHalfSize: CGFloat = 200.0) {
        self.viewportW = viewportW
        self.viewportH = viewportH
        self.objectHalfSize = objectHalfSize > 0 ? objectHalfSize : 200.0
        self.panelW = viewportW
        self.panelH = viewportH
    }

    public func setViewport(_ w: CGFloat, _ h: CGFloat) {
        viewportW = w
        viewportH = h
        panelX = 0
        panelY = 0
        panelW = w
        panelH = h
    }

    public func getViewport() -> CGSize {
        CGSize(width: viewportW, height: viewportH)
    }

    /// Split ('cross') view: the renderer sets one rect per panel.
    public func setPanelRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        panelX = x
        panelY = y
        panelW = w
        panelH = h
    }

    public func getPanelRect() -> CGRect {
        CGRect(x: panelX, y: panelY, width: panelW, height: panelH)
    }

    public func setObjectHalfSize(_ half: CGFloat) {
        if half > 0 { objectHalfSize = half }
    }

    public func getObjectHalfSize() -> CGFloat { objectHalfSize }

    public func getScaleFactor() -> CGFloat { scale }
    public func setScaleFactor(_ f: CGFloat) { scale = f }

    /// Back to the Android initial state: scale 0.5, no translation, no rotation.
    public func reset() {
        scale = 0.5
        tx = 0.0
        ty = 0.0
        rotationDeg = 0.0
    }

    // MARK: - Screen ↔ world ↔ object

    /// screen px → world(q) units; k = px per world unit.
    public func pixelsPerWorldUnit() -> CGFloat {
        guard objectHalfSize != 0 else { return 1 }
        return panelH / (2.0 * objectHalfSize)
    }

    public func screenToWorld(x: CGFloat, y: CGFloat) -> CGPoint {
        let k = pixelsPerWorldUnit()
        guard k != 0 else { return .zero }
        return CGPoint(x: (x - (panelX + panelW / 2.0)) / k,
                       y: (y - (panelY + panelH / 2.0)) / k)
    }

    public func worldToScreen(x wx: CGFloat, y wy: CGFloat) -> CGPoint {
        let k = pixelsPerWorldUnit()
        return CGPoint(x: panelX + panelW / 2.0 + k * wx,
                       y: panelY + panelH / 2.0 + k * wy)
    }

    public func worldToObject(x wx: CGFloat, y wy: CGFloat) -> CGPoint {
        let rad = Double(rotationDeg) * .pi / 180.0
        let cosR = CGFloat(cos(rad))
        let sinR = CGFloat(sin(rad))
        let dx = wx - tx
        let dy = wy - ty
        guard scale != 0 else { return .zero }
        return CGPoint(x: (cosR * dx + sinR * dy) / scale,
                       y: (-sinR * dx + cosR * dy) / scale)
    }

    public func objectToWorld(x px: CGFloat, y py: CGFloat) -> CGPoint {
        let rad = Double(rotationDeg) * .pi / 180.0
        let cosR = CGFloat(cos(rad))
        let sinR = CGFloat(sin(rad))
        let sx = scale * px
        let sy = scale * py
        return CGPoint(x: tx + cosR * sx - sinR * sy,
                       y: ty + sinR * sx + cosR * sy)
    }

    public func screenToObject(x: CGFloat, y: CGFloat) -> CGPoint {
        let w = screenToWorld(x: x, y: y)
        return worldToObject(x: w.x, y: w.y)
    }

    public func objectToScreen(x px: CGFloat, y py: CGFloat) -> CGPoint {
        let w = objectToWorld(x: px, y: py)
        return worldToScreen(x: w.x, y: w.y)
    }

    // MARK: - Java AbstractGLSurfaceView equivalents

    public func getWorldXFromTouchX(_ x: CGFloat) -> CGFloat {
        screenToWorld(x: x, y: 0).x
    }

    public func getWorldYFromTouchY(_ y: CGFloat) -> CGFloat {
        screenToWorld(x: 0, y: y).y
    }

    public func getWorldValFromTouchPx(_ v: CGFloat) -> CGFloat {
        v / pixelsPerWorldUnit()
    }

    public func getObjectValFromTouchPx(_ v: CGFloat) -> CGFloat {
        guard scale != 0 else { return 0 }
        return getWorldValFromTouchPx(v) / scale
    }

    public func getObjectPointFromWorldPointDouble(_ wx: CGFloat, _ wy: CGFloat) -> CGPoint {
        worldToObject(x: wx, y: wy)
    }

    public func getObjectPointFromWorldPointFloat(_ wx: CGFloat, _ wy: CGFloat) -> CGPoint {
        worldToObject(x: wx, y: wy)
    }

    public func getObjectRadiusFromTouchPxRadius() -> CGFloat {
        getObjectValFromTouchPx(ViewTransform.SCREEN_TOUCH_RADIUS_DP)
    }

    public func getObjectLengthFromTouchPixelSelectDashLength() -> CGFloat {
        getObjectValFromTouchPx(ViewTransform.SELECTION_RECT_DASH_LENGTH_DP)
    }

    // MARK: - Gestures (canvas px)

    /// Pinch zoom about a screen focus; mirrors ScaleListener: the cumulative scale is
    /// clamped to Constant.MIN/MAX_SCALE_FACTOR and the transform is applied only when
    /// the new cumulative factor is in range. Returns false when clamped.
    @discardableResult
    public func zoomAt(factor: CGFloat, focusX: CGFloat, focusY: CGFloat) -> Bool {
        let next = scale * factor
        if next > Camera.MAX_SCALE_FACTOR || next < Camera.MIN_SCALE_FACTOR { return false }
        scaleTransformM(factor: factor, focusX: focusX, focusY: focusY)
        return true
    }

    /// Two-finger pan: dx/dy are finger movement deltas in canvas px.
    public func panBy(dx: CGFloat, dy: CGFloat) {
        translateTransformM(dxPx: dx, dyPx: dy)
    }

    /// Two-finger rotation about a screen point (deg delta; positive = clockwise).
    public func rotateAt(deg: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        rotateTranslateTransformM(deg: deg, centerX: centerX, centerY: centerY, dxPx: 0, dyPx: 0)
    }

    public func scaleTransformM(factor: CGFloat, focusX: CGFloat, focusY: CGFloat) {
        let q = screenToWorld(x: focusX, y: focusY)
        scaleTransformWorld(factor: factor, worldX: q.x, worldY: q.y)
    }

    public func scaleTransformWorld(factor: CGFloat, worldX wx: CGFloat, worldY wy: CGFloat) {
        tx = wx + factor * (tx - wx)
        ty = wy + factor * (ty - wy)
        scale *= factor
    }

    public func translateTransformM(dxPx: CGFloat, dyPx: CGFloat) {
        let k = pixelsPerWorldUnit()
        guard k != 0 else { return }
        tx += dxPx / k
        ty += dyPx / k
    }

    public func translateTransformWorld(dx: CGFloat, dy: CGFloat) {
        tx += dx
        ty += dy
    }

    public func rotateTranslateTransformM(deg: CGFloat, centerX: CGFloat, centerY: CGFloat,
                                          dxPx: CGFloat, dyPx: CGFloat) {
        let q = screenToWorld(x: centerX, y: centerY)
        let k = pixelsPerWorldUnit()
        guard k != 0 else { return }
        rotateTranslateTransformWorld(deg: deg, worldX: q.x, worldY: q.y, dx: dxPx / k, dy: dyPx / k)
    }

    public func rotateTranslateTransformWorld(deg: CGFloat, worldX wx: CGFloat, worldY wy: CGFloat,
                                              dx: CGFloat, dy: CGFloat) {
        let rad = Double(deg) * .pi / 180.0
        let cosR = CGFloat(cos(rad))
        let sinR = CGFloat(sin(rad))
        let ftx = tx - wx
        let fty = ty - wy
        tx = wx + dx + cosR * ftx - sinR * fty
        ty = wy + dy + sinR * ftx + cosR * fty
        rotationDeg += deg
    }

    /// Object-space scale currently applied (for line-width math).
    public func objectScale() -> CGFloat {
        abs(scale)
    }
}
