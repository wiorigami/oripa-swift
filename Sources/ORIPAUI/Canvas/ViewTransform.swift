// Port of `oripa-port/src/js/render/ViewTransform.js`
// (com.origamitoolbox.oripa.editor.glview.AbstractGLSurfaceView /
//  AbstractDoubleGLSurfaceView / GLUtil).
//
// The Android renderer accumulates a 2x2 affine object→world matrix plus the gesture
// scale factor; viewport projection is a uniform scale around the viewport centre:
//
//   world(q) = A * object + t             A = [[a,b],[c,d]]
//   screen   = viewportCentre + k * q     k = viewportH / (2 * objectHalfSize)
//
// The GL projection is y-flipped, so object Y positive is DOWN on screen (this matches
// the Java touch→world math, the SVG/PNG exporters and the reference web port).
//
// All public gesture methods take/return canvas px. The `…World` variants take
// crease-pattern/world units like the Java renderer. This file intentionally has no
// ORIPACore dependency (pure CoreGraphics/Foundation math) so the canvas layer stays
// usable before the core model types land; conversion to `PointDouble` lives in the
// editor bridge.
import CoreGraphics
import Foundation

public final class ViewTransform {
    // MARK: - State

    public var viewportW: CGFloat
    public var viewportH: CGFloat
    /// Crease-pattern half size (`cp.creasePatternHalfSize`, 200 by default).
    public var objectHalfSize: CGFloat = 200.0
    /// Android `mScaleFactor` (initial 0.5), tracked separately from the matrix.
    public var scaleFactor: CGFloat = 0.5

    // Matrix (Double math, same as the Java `double` matrix).
    public var a: Double = 0.5
    public var b: Double = 0.0
    public var c: Double = 0.0
    public var d: Double = 0.5
    public var tx: Double = 0.0
    public var ty: Double = 0.0

    // MARK: - Constants

    /// `Constant.SCREEN_TOUCH_RADIUS_DP` (16 dp).
    public static let SCREEN_TOUCH_RADIUS_DP: CGFloat = 16.0
    /// `Constant.SELECTION_RECT_DASH_LENGTH_DP` (10 dp).
    public static let SELECTION_RECT_DASH_LENGTH_DP: CGFloat = 10.0

    // MARK: - Init

    public init(viewportW: CGFloat = 0, viewportH: CGFloat = 0) {
        self.viewportW = viewportW
        self.viewportH = viewportH
        reset()
    }

    public func setViewport(_ w: CGFloat, _ h: CGFloat) {
        viewportW = w
        viewportH = h
    }

    public func setObjectHalfSize(_ half: CGFloat) {
        if half > 0 { objectHalfSize = half }
    }

    public func getObjectHalfSize() -> CGFloat { objectHalfSize }

    public func setScaleFactor(_ f: CGFloat) { scaleFactor = f }

    public func getScaleFactor() -> CGFloat { scaleFactor }

    /// Android `initializeRenderer()`: identity then `scaleTransformM(0.5, 0, 0)`.
    public func reset() {
        a = 0.5; b = 0.0; c = 0.0; d = 0.5
        tx = 0.0; ty = 0.0
    }

    public func identityTransformM() {
        a = 1.0; b = 0.0; c = 0.0; d = 1.0
        tx = 0.0; ty = 0.0
    }

    // MARK: - Touch ↔ world ↔ object

    public func pixelsPerWorldUnit() -> CGFloat {
        guard objectHalfSize != 0 else { return 1 }
        return viewportH / (2.0 * objectHalfSize)
    }

    public func worldXFromTouchX(_ x: CGFloat) -> CGFloat {
        (x - viewportW / 2.0) / pixelsPerWorldUnit()
    }

    public func worldYFromTouchY(_ y: CGFloat) -> CGFloat {
        (y - viewportH / 2.0) / pixelsPerWorldUnit()
    }

    public func getWorldXFromTouchX(_ x: CGFloat) -> CGFloat { worldXFromTouchX(x) }
    public func getWorldYFromTouchY(_ y: CGFloat) -> CGFloat { worldYFromTouchY(y) }

    /// px → world units (single full-canvas viewport).
    public func getWorldValFromTouchPx(_ v: CGFloat) -> CGFloat {
        v / pixelsPerWorldUnit()
    }

    /// px → object units (divide by the current gesture scale factor).
    public func getObjectValFromTouchPx(_ v: CGFloat) -> CGFloat {
        getWorldValFromTouchPx(v) / scaleFactor
    }

    public func getObjectRadiusFromTouchPxRadius() -> CGFloat {
        getObjectValFromTouchPx(Self.SCREEN_TOUCH_RADIUS_DP)
    }

    public func getObjectLengthFromTouchPixelSelectDashLength() -> CGFloat {
        getObjectValFromTouchPx(Self.SELECTION_RECT_DASH_LENGTH_DP)
    }

    public func objectToWorld(x ox: CGFloat, y oy: CGFloat) -> CGPoint {
        CGPoint(x: CGFloat(a * Double(ox) + b * Double(oy) + tx),
                y: CGFloat(c * Double(ox) + d * Double(oy) + ty))
    }

    public func worldToObject(x wx: CGFloat, y wy: CGFloat) -> CGPoint {
        let det = a * d - b * c
        guard det != 0 else { return .zero }
        let dx = Double(wx) - tx
        let dy = Double(wy) - ty
        return CGPoint(x: CGFloat((d * dx - b * dy) / det),
                       y: CGFloat((-c * dx + a * dy) / det))
    }

    public func objectToScreen(x ox: CGFloat, y oy: CGFloat) -> CGPoint {
        let q = objectToWorld(x: ox, y: oy)
        let k = pixelsPerWorldUnit()
        return CGPoint(x: viewportW / 2.0 + k * q.x, y: viewportH / 2.0 + k * q.y)
    }

    public func screenToObject(x: CGFloat, y: CGFloat) -> CGPoint {
        worldToObject(x: worldXFromTouchX(x), y: worldYFromTouchY(y))
    }

    public func getObjectPointFromWorldPointDouble(_ wx: CGFloat, _ wy: CGFloat) -> CGPoint {
        worldToObject(x: wx, y: wy)
    }

    public func getObjectPointFromWorldPointFloat(_ wx: CGFloat, _ wy: CGFloat) -> CGPoint {
        worldToObject(x: wx, y: wy)
    }

    /// world → screen px helper (used by the renderers).
    public func worldToScreen(x wx: CGFloat, y wy: CGFloat) -> CGPoint {
        let k = pixelsPerWorldUnit()
        return CGPoint(x: viewportW / 2.0 + k * wx, y: viewportH / 2.0 + k * wy)
    }

    /// Length of an object-space length on screen (uniform scale).
    public func objectLengthToScreen(_ length: CGFloat) -> CGFloat {
        let det = abs(a * d - b * c)
        return length * CGFloat(sqrt(det)) * pixelsPerWorldUnit()
    }

    public func objectScale() -> CGFloat {
        let det = abs(a * d - b * c)
        return CGFloat(sqrt(det))
    }

    // MARK: - Java renderer transform API (world-space focus / deltas)

    public func scaleTransformM(factor: CGFloat, focusXPx: CGFloat, focusYPx: CGFloat) {
        let wx = worldXFromTouchX(focusXPx)
        let wy = worldYFromTouchY(focusYPx)
        scaleTransformWorldM(factor: factor, wx: wx, wy: wy)
    }

    public func scaleTransformWorldM(factor: CGFloat, wx: CGFloat, wy: CGFloat) {
        let f = Double(factor)
        a *= f; b *= f
        c *= f; d *= f
        tx = Double(wx) + f * (tx - Double(wx))
        ty = Double(wy) + f * (ty - Double(wy))
    }

    public func translateTransformM(dxPx: CGFloat, dyPx: CGFloat) {
        let k = pixelsPerWorldUnit()
        guard k != 0 else { return }
        tx += Double(dxPx / k)
        ty += Double(dyPx / k)
    }

    public func translateTransformWorldM(dx: CGFloat, dy: CGFloat) {
        tx += Double(dx)
        ty += Double(dy)
    }

    public func rotateTranslateTransformM(deg: CGFloat, centerXPx: CGFloat, centerYPx: CGFloat,
                                          dxPx: CGFloat, dyPx: CGFloat) {
        let wx = worldXFromTouchX(centerXPx)
        let wy = worldYFromTouchY(centerYPx)
        let k = pixelsPerWorldUnit()
        guard k != 0 else { return }
        rotateTranslateTransformWorldM(deg: deg, wx: wx, wy: wy, dx: dxPx / k, dy: dyPx / k)
    }

    public func rotateTranslateTransformWorldM(deg: CGFloat, wx: CGFloat, wy: CGFloat,
                                               dx: CGFloat, dy: CGFloat) {
        let rad = Double(deg) * .pi / 180.0
        let cosR = cos(rad)
        let sinR = sin(rad)
        let na = cosR * a - sinR * c
        let nb = cosR * b - sinR * d
        let nc = sinR * a + cosR * c
        let nd = sinR * b + cosR * d
        let ntx = tx - Double(wx)
        let nty = ty - Double(wy)
        a = na; b = nb; c = nc; d = nd
        tx = Double(wx) + Double(dx) + cosR * ntx - sinR * nty
        ty = Double(wy) + Double(dy) + sinR * ntx + cosR * nty
    }
}
