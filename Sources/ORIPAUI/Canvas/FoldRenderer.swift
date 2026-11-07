// Port of `oripa-port/src/js/render/FoldRenderer.js` (ORIPA.render.FoldRenderer) — the
// Canvas-2D rebuild of the Android GLRendererFoldCpXray / GLRendererFoldCpOverlap /
// GLRendererFoldCpCross renderers, including the double ('cross line') view.
//
// Drawing goes through a Core Graphics context so the same code serves the live fold
// screen (SwiftUI `Canvas` -> `GraphicsContext.withCGContext`) and the offscreen PNG
// export (`FoldPNGExport.swift`). All coordinates handled here are "screen CSS px"
// (points) with the origin at the top-left and Y down, exactly like the web canvas.
// Object coordinates are crease-pattern / folded-model coordinates (Y positive down);
// the camera converts between the two.
//
// Render data is built internally from the FoldedModel (`GLDataFmXrayCross`,
// `GLDataFmOverlap`, `GLDataFmCrossLine` — owned by the fold-io workstream) like
// `PaintCpFragment` did in the Android app. Cameras are owned and mutated by the UI
// (Screens/Fold); the renderer only assigns viewport/panel/objectHalfSize in `resize`.
//
// Visual contract: `oripa-port/docs/render-api.md` § FoldRenderer.
import SwiftUI
import CoreGraphics
import ORIPACore

// MARK: - Mode / panel / feedback value types

/// Folded-model view mode selected by the fold screen spinner (`fold_action_spinner_labels`).
public enum FoldMode: String, CaseIterable, Sendable {
    /// 0 — "X-Ray / Wireframe" (GLRendererFoldCpXray).
    case xray
    /// 1 — "Overlap [BETA]" (GLRendererFoldCpOverlap).
    case overlap
    /// 2 — "Cut Line" (GLRendererFoldCpCross, split view).
    case cross

    /// JS `MODES` order; spinner index <-> mode.
    public var spinnerIndex: Int {
        switch self {
        case .xray: return 0
        case .overlap: return 1
        case .cross: return 2
        }
    }

    public init?(spinnerIndex: Int) {
        guard spinnerIndex >= 0, spinnerIndex < FoldMode.allCases.count else { return nil }
        self = FoldMode.allCases[spinnerIndex]
    }
}

/// One panel of the Cut Line split view: top = crease pattern + magenta slice line,
/// bottom = folded model + magenta cut line (portrait); landscape swaps left/right.
public enum FoldPanel: String, Sendable {
    case top
    case bottom
}

/// Pink touch-circle feedback (Java `GLCompositeCircle` / `showTouchCircleCp/Fm`).
/// Coordinates are object coordinates, `radius` object units.
public struct FoldTouchCircle: Equatable, Sendable {
    public var panel: FoldPanel
    public var x: CGFloat
    public var y: CGFloat
    public var radius: CGFloat

    public init(panel: FoldPanel, x: CGFloat, y: CGFloat, radius: CGFloat) {
        self.panel = panel
        self.x = x
        self.y = y
        self.radius = radius
    }
}

/// The two cameras of the 'cross' split view (Android double renderer). The renderer
/// assigns each camera its panel rect on `resize`, so camera gestures accept canvas px.
public struct FoldCameraPair {
    public var top: Camera
    public var bottom: Camera

    public init(top: Camera, bottom: Camera) {
        self.top = top
        self.bottom = bottom
    }
}

// MARK: - Renderer preferences / options

/// `rendererPreferences()` in `fold.js`: parsed from the Android SharedPreferences (the
/// renderer never reads prefs itself).
public struct FoldRenderPreferences: Equatable {
    public var wireframe: Bool
    public var overlapEnabled: Bool
    public var overlapShadow: Bool
    public var flip: Bool
    public var frontColor: UInt32
    public var backColor: UInt32
    public var lineColor: UInt32

    public init(wireframe: Bool = false,
                overlapEnabled: Bool = true,
                overlapShadow: Bool = false,
                flip: Bool = false,
                frontColor: UInt32 = FoldRenderer.DEFAULT_FRONT_COLOR,
                backColor: UInt32 = FoldRenderer.DEFAULT_BACK_COLOR,
                lineColor: UInt32 = FoldRenderer.DEFAULT_LINE_COLOR) {
        self.wireframe = wireframe
        self.overlapEnabled = overlapEnabled
        self.overlapShadow = overlapShadow
        self.flip = flip
        self.frontColor = frontColor
        self.backColor = backColor
        self.lineColor = lineColor
    }
}

/// `setOptions({touchCircle: ... | null})` update: either show the gesture feedback or
/// clear it (the JS uses `null`, Swift needs an explicit case).
public enum FoldTouchCircleUpdate: Equatable {
    case set(FoldTouchCircle)
    case clear
}

/// `rendererOptions()` in `fold.js`. Every field is optional: `setOptions` only
/// overwrites the fields that are present (`undefined` in the JS).
public struct FoldRenderOptions {
    public var wireframe: Bool?
    public var flip: Bool?
    public var frontColor: UInt32?
    public var backColor: UInt32?
    public var lineColor: UInt32?
    public var overlapShadow: Bool?
    public var overlapEnabled: Bool?
    public var crossPosition: Int?
    public var crossAngleDeg: Int?
    public var showCrossButtons: Bool?
    /// Java `showCrossLineActive`: the cut line widens while dragging (6 -> 10 GL px).
    public var crossLineActive: Bool?
    /// `touchCircle: {panel,x,y,radius}` gesture feedback; `nil` means "not set".
    public var touchCircle: FoldTouchCircleUpdate?

    public init() {}
}

/// Widths/alphas from `RenderUtil.style` (`REFERENCE_DENSITY = 3`, the xxhdpi APK device
/// class: GL px / 3 = CSS px = SwiftUI points).
public enum FoldRenderStyle {
    public static let referenceDensity: CGFloat = 3.0

    /// `RenderUtil.glPx(n)`.
    public static func glPx(_ n: CGFloat) -> CGFloat { n / referenceDensity }

    /// GL_LINES folding-model crease width: gl 4 px.
    public static let foldCreaseWidth = glPx(CGFloat(Constant.LINE_WIDTH_FOLD_CP_CREASE))
    /// GL_LINES folding-model boundary width: gl 10 px.
    public static let foldBoundaryWidth = glPx(CGFloat(Constant.LINE_WIDTH_FOLD_CP_BOUNDARY))
    /// Typed crease-pattern lines in the Cut Line CP panel: gl 3 px.
    public static let cpLineWidth = glPx(CGFloat(Constant.LINE_WIDTH_DEFAULT))
    /// Magenta cut/slice line: gl 6 px (10 px while the line is dragged).
    public static let crossLineWidth = glPx(CGFloat(Constant.LINE_WIDTH_FOLD_CP_CROSS))
    public static let crossLineWidthActive = glPx(CGFloat(Constant.LINE_WIDTH_FOLD_CP_CROSS_THICK))
    /// Grey viewport divider of the double view: gl 10 px.
    public static let viewportDividerWidth = glPx(CGFloat(Constant.LINE_WIDTH_SCREEN_DIVIDER))
    /// GLPolygonTwoColorLineShadow: outline half width = 1 dp, shadow band = 12x.
    public static let overlapLineHalfWidth = CGFloat(Constant.LINE_HALF_WIDTH_FOLD_CP_OVERLAP_DP)
    public static let overlapShadowWidth = overlapLineHalfWidth * 12.0
    public static let overlapShadowAlpha: CGFloat = 0.38
    /// GLCompositeCircle touch feedback alpha.
    public static let touchCircleAlpha: CGFloat = 0.38
}

// MARK: - Renderer

/// Port of `ORIPA.render.FoldRenderer`. One instance per mode (the fold screen keeps one
/// per spinner item, like the three eagerly created GL views of `FragmentFoldCp`).
@MainActor
public final class FoldRenderer: ObservableObject {
    // Defaults of `RenderUtil.DEFAULT_*` / `FoldCpOverlapSettingsDialogFragment`.
    public static let DEFAULT_FRONT_COLOR: UInt32 = 0xFFFF_91AE
    public static let DEFAULT_BACK_COLOR: UInt32 = 0xFF00_B7D9
    public static let DEFAULT_LINE_COLOR: UInt32 = 0xFF50_5050

    /// `GLPolygonTwoColor` CP face colours (cross view CP panel): #FFF4F7 / #E6F8FB.
    public static let CP_FACE_FRONT = RGB(1.0, 0.956_862_75, 0.968_627_45)
    public static let CP_FACE_BACK = RGB(0.901_960_8, 0.972_549, 0.984_313_7)

    // MARK: Public state

    public private(set) var mode: FoldMode = .xray
    public private(set) var cp: CreasePattern?
    public private(set) var fm: FoldedModel?
    public private(set) var crossLineManager: CrossLineManager?

    /// Full-screen modes camera (xray/overlap). Mutated by the UI gestures.
    public var camera: Camera
    /// Split view cameras; `nil` until created by `setMode(.cross)` + fold model, or set by `setCameras`.
    public private(set) var cameras: FoldCameraPair?
    /// True while the cross cameras were created by the renderer (Android default cameras).
    public private(set) var defaultCameras: Bool = true

    /// `rendererPreferences()`.
    public var preferences = FoldRenderPreferences()
    /// `rendererOptions()`.
    public private(set) var options = FoldRenderOptions()

    /// Canvas background; white by default (Java clears to white). `nil` = transparent.
    public var background: CGColor? = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

    public var cssW: CGFloat = 1
    public var cssH: CGFloat = 1

    /// Bumped on every requested redraw so SwiftUI (and the fold screen) can invalidate.
    @Published public private(set) var revision: Int = 0

    // MARK: Private state (JS fields)

    private var dataDirty = true
    private var xrayGeometry: FoldXrayGeometry?
    private var overlapSetsData: [FoldOverlapSet]?
    private var overlapShadowBuilt = false
    private var crossLineData: FoldCrossLineData?
    private var crossLineKey: String?
    private var touchCircleStorage: FoldTouchCircle?
    /// JS `options.touchCircle` (fold screen gesture feedback), set through `setOptions`.
    private var touchCircleOverride: FoldTouchCircle?
    /// JS `options.touchCircle !== undefined` — distinguishes "not set" from "cleared".
    private var touchCircleOptionActive = false

    public init() {
        self.camera = Camera()
    }

    // MARK: - Configuration (JS prototype setters)

    public func setMode(_ mode: FoldMode) {
        self.mode = mode
        if mode == .cross { ensureCameras(force: false) }
        dataDirty = true
        requestDraw()
    }

    public func setCreasePattern(_ cp: CreasePattern?) {
        self.cp = cp
        if mode == .cross && defaultCameras { ensureCameras(force: true) }
        requestDraw()
    }

    public func setFoldedModel(_ fm: FoldedModel?) {
        self.fm = fm
        rebuildData()
        if mode == .cross && defaultCameras { ensureCameras(force: true) }
        requestDraw()
    }

    public func setCrossLineManager(_ crossLineManager: CrossLineManager?) {
        self.crossLineManager = crossLineManager
        crossLineKey = nil
        crossLineData = nil
        requestDraw()
    }

    public func setPreferences(_ preferences: FoldRenderPreferences) {
        self.preferences = preferences
        dataDirty = true
        requestDraw()
    }

    /// Merge semantics of `FoldRenderer.prototype.setOptions` (only present keys overwrite;
    /// `undefined`/`null` leaves the previous value, except `touchCircle`).
    public func setOptions(_ opts: FoldRenderOptions) {
        var dirty = false
        if let v = opts.wireframe { options.wireframe = v; dirty = true }
        if let v = opts.flip { options.flip = v; dirty = true }
        if let v = opts.frontColor { options.frontColor = v }
        if let v = opts.backColor { options.backColor = v }
        if let v = opts.lineColor { options.lineColor = v }
        if let v = opts.overlapShadow { options.overlapShadow = v; dirty = true }
        if let v = opts.overlapEnabled { options.overlapEnabled = v; dirty = true }
        if let v = opts.crossPosition { options.crossPosition = v; dirty = true }
        if let v = opts.crossAngleDeg { options.crossAngleDeg = v; dirty = true }
        if let v = opts.showCrossButtons { options.showCrossButtons = v }
        if let v = opts.crossLineActive { options.crossLineActive = v }
        if let update = opts.touchCircle {
            touchCircleOptionActive = true
            switch update {
            case .set(let circle): touchCircleOverride = circle
            case .clear: touchCircleOverride = nil
            }
        }
        if dirty { dataDirty = true }
        requestDraw()
    }

    /// `setOptions({touchCircle: ...})` convenience for the fold screen gestures.
    public func setTouchCircleOption(_ circle: FoldTouchCircle?) {
        touchCircleOptionActive = true
        touchCircleOverride = circle
        requestDraw()
    }

    /// `setOptions({touchCircle: null})` — clear the gesture feedback override.
    public func clearTouchCircleOption() {
        touchCircleOptionActive = true
        touchCircleOverride = nil
        requestDraw()
    }

    public func setCamera(_ camera: Camera) {
        self.camera = camera
        syncFullCamera()
        requestDraw()
    }

    public func setCameras(_ cameras: FoldCameraPair) {
        self.cameras = cameras
        defaultCameras = false
        syncCrossCameras()
        requestDraw()
    }

    // MARK: - Cameras

    private var fmHalfSize: CGFloat {
        CGFloat(fm?.foldedModelHalfSize ?? 200.0)
    }

    private func syncFullCamera() {
        camera.setViewport(cssW, cssH)
        camera.setObjectHalfSize(fmHalfSize)
    }

    private func makeDefaultFmCamera() -> Camera {
        let cam = Camera()
        cam.setViewport(cssW, cssH)
        cam.setObjectHalfSize(fmHalfSize)
        return cam
    }

    /// `defaultCpCamera`: the Android CP-panel fit
    /// `S(0.5) -> T(-centre*0.5) -> S(fmHalf/maxHalf)`.
    private func makeDefaultCpCamera() -> Camera {
        let cam = makeDefaultFmCamera()
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        var maxHalf: CGFloat = 1.0
        if let cp {
            let maxHalfSize = cp.minMaxCheck.getMaxHalfSize()
            if maxHalfSize > 0 {
                centerX = CGFloat(cp.minMaxCheck.getCenterX())
                centerY = CGFloat(cp.minMaxCheck.getCenterY())
                maxHalf = fmHalfSize / CGFloat(maxHalfSize)
            } else if cp.creasePatternHalfSize > 0 {
                maxHalf = fmHalfSize / CGFloat(cp.creasePatternHalfSize)
            }
        }
        cam.scale = 0.5 * maxHalf
        cam.tx = -0.5 * maxHalf * centerX
        cam.ty = -0.5 * maxHalf * centerY
        return cam
    }

    private func ensureCameras(force: Bool) {
        if cameras == nil || (force && defaultCameras) {
            cameras = FoldCameraPair(top: makeDefaultCpCamera(), bottom: makeDefaultFmCamera())
            defaultCameras = true
        }
        syncCrossCameras()
    }

    /// Portrait: CP top / FM bottom. Landscape: CP right / FM left (Android double renderer).
    private func syncCrossCameras() {
        guard let cams = cameras else { return }
        let w = cssW
        let h = cssH
        for pair in [(cams.top, FoldPanel.top), (cams.bottom, FoldPanel.bottom)] {
            let cam = pair.0
            cam.setViewport(w, h)
            cam.setObjectHalfSize(fmHalfSize)
            let rect = panelRect(pair.1)
            cam.setPanelRect(x: rect.minX, y: rect.minY, w: rect.width, h: rect.height)
        }
    }

    /// Panel rects in canvas points: portrait CP top / FM bottom, landscape CP right / FM left.
    public func panelRect(_ which: FoldPanel) -> CGRect {
        let w = cssW
        let h = cssH
        if which == .top {
            return (w <= h)
                ? CGRect(x: 0, y: 0, width: w, height: h / 2)
                : CGRect(x: w / 2, y: 0, width: w / 2, height: h)
        }
        return (w <= h)
            ? CGRect(x: 0, y: h / 2, width: w, height: h / 2)
            : CGRect(x: 0, y: 0, width: w / 2, height: h)
    }

    /// Which half of the cross view a canvas point is in.
    public func hitPanel(x: CGFloat, y: CGFloat) -> FoldPanel {
        if cssW <= cssH { return y < cssH / 2 ? .top : .bottom }
        return x >= cssW / 2 ? .top : .bottom
    }

    // MARK: - Effective flags (options override preferences)

    private var wireframeFlag: Bool {
        options.wireframe ?? preferences.wireframe
    }

    private var overlapShadowFlag: Bool {
        options.overlapShadow ?? preferences.overlapShadow
    }

    private var overlapEnabledFlag: Bool {
        options.overlapEnabled ?? preferences.overlapEnabled
    }

    private var crossLineActiveFlag: Bool {
        options.crossLineActive ?? false
    }

    /// `_crossParams()`: effective cut-line angle/position (Int, Java `Math.round`).
    private func crossParams() -> (angle: Int, position: Int)? {
        guard let fm else { return nil }
        let angle: Int
        if let a = options.crossAngleDeg {
            angle = a
        } else if let clm = crossLineManager {
            angle = clm.getCurrentCrossLineAngleDeg()
        } else {
            angle = fm.crossLine.getAngleDegDefaultMagnitude()
        }
        let position: Int
        if let p = options.crossPosition {
            position = p
        } else if let clm = crossLineManager {
            position = clm.getCurrentCrossLinePosition()
        } else {
            position = fm.crossLine.getPositionDefaultMagnitude()
        }
        return (angle, position)
    }

    // MARK: - Data building

    /// `_buildData()`: x-ray/cross geometry + (lazily) the overlap data sets + cut line.
    private func rebuildData() {
        dataDirty = false
        xrayGeometry = nil
        overlapSetsData = nil
        crossLineData = nil
        crossLineKey = nil
        guard let fm else { return }
        let raw = GLDataFmXrayCross.getRenderData(fm.mVertices, fm.mHalfEdges, fm.mFaces)
        xrayGeometry = FoldXrayGeometry(raw: raw, fm: fm)
        updateCrossLineData()
    }

    /// `_withShadow()` / `_overlapEnabled()`: the Java builds *blank* overlap data when
    /// `paint_pref_fold_overlap=false`, so the Overlap view (and its PNG export) is empty.
    private func ensureOverlapData() {
        guard let fm else { return }
        guard overlapEnabledFlag else {
            overlapSetsData = nil
            return
        }
        let withShadow = overlapShadowFlag
        if overlapSetsData == nil || overlapShadowBuilt != withShadow {
            let sets = GLDataFmOverlap.getRenderDataSplit(fm.sortedFaces,
                                                          fm.sortedFacesReverse,
                                                          withShadow)
            overlapSetsData = sets.map(FoldOverlapSet.init(raw:))
            overlapShadowBuilt = withShadow
        }
    }

    /// `_updateCrossLineData()`: rebuilds when angle/position changed and writes the
    /// current values + render data back to the CrossLineManager (Android behaviour).
    private func updateCrossLineData() {
        guard let fm, let params = crossParams() else { return }
        let key = "\(params.angle):\(params.position)"
        if crossLineData == nil || crossLineKey != key {
            let raw = GLDataFmCrossLine.getRenderData(fm.mFaces,
                                                      fm.crossLine,
                                                      params.angle,
                                                      params.position)
            crossLineData = FoldCrossLineData(cpPosition: raw.cpPosition, fmPosition: raw.fmPosition)
            crossLineKey = key
            if let clm = crossLineManager {
                clm.currentCrossLineAngleDeg = params.angle
                clm.currentCrossLinePosition = params.position
                clm.crossLineRenderData = raw
            }
        }
    }

    // MARK: - Touch circle feedback

    public func showTouchCircle(panel: FoldPanel, x: CGFloat, y: CGFloat, radius: CGFloat) {
        touchCircleStorage = FoldTouchCircle(panel: panel, x: x, y: y, radius: radius)
        requestDraw()
    }

    public func showTouchCircleCp(x: CGFloat, y: CGFloat, radius: CGFloat) {
        showTouchCircle(panel: .top, x: x, y: y, radius: radius)
    }

    public func showTouchCircleFm(x: CGFloat, y: CGFloat, radius: CGFloat) {
        showTouchCircle(panel: .bottom, x: x, y: y, radius: radius)
    }

    public func hideTouchCircle() {
        touchCircleStorage = nil
        requestDraw()
    }

    private var effectiveTouchCircle: FoldTouchCircle? {
        touchCircleOptionActive ? touchCircleOverride : touchCircleStorage
    }

    // MARK: - Layout / redraw

    /// `resize(cssW, cssH)`: assigns the viewport, object half size and (cross) panel rects
    /// to the cameras. The UI calls this from a GeometryReader / onGeometryChange.
    public func resize(_ width: CGFloat, _ height: CGFloat) {
        let w = max(1, width)
        let h = max(1, height)
        cssW = w
        cssH = h
        syncFullCamera()
        ensureCameras(force: false)
        syncCrossCameras()
        requestDraw()
    }

    /// Synchronise the drawing size with the actual canvas size (defensive: the UI is
    /// expected to call `resize`, but a missed geometry change must not corrupt the view).
    private func syncCanvasSize(_ size: CGSize) {
        let w = max(1, size.width)
        let h = max(1, size.height)
        guard abs(w - cssW) > 0.01 || abs(h - cssH) > 0.01 else { return }
        cssW = w
        cssH = h
        syncFullCamera()
        ensureCameras(force: false)
        syncCrossCameras()
    }

    /// JS `requestDraw()` (rAF-batched): here the SwiftUI invalidation token.
    public func requestDraw() {
        revision &+= 1
    }

    // MARK: - Drawing entry points

    /// Draw into a SwiftUI `Canvas` `GraphicsContext` (live fold screen).
    ///
    /// SwiftUI's canvas coordinate space is Y-down (top-left origin) and the CG context it
    /// hands out is composited back into that space, so **no extra flip** is applied here —
    /// the shared drawing code below runs in screen space directly.
    public func draw(in context: GraphicsContext, size: CGSize) {
        context.withCGContext { cg in
            self.render(cg, size: size, flipY: false)
        }
    }

    /// Draw into a Core Graphics bitmap context (offscreen PNG export). Bitmap contexts are
    /// Y-up, so the renderer applies the top-left/Y-down flip itself. User coordinates are
    /// screen points with the origin at the top-left and Y down.
    public func draw(in cg: CGContext, size: CGSize) {
        render(cg, size: size, flipY: cg.ctm.d > 0)
    }

    private func render(_ cg: CGContext, size: CGSize, flipY: Bool) {
        guard size.width > 0.5, size.height > 0.5 else { return }
        syncCanvasSize(size)
        if dataDirty { rebuildData() }

        cg.saveGState()
        defer { cg.restoreGState() }
        if flipY {
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
        }
        cg.setLineCap(.butt)
        cg.setLineJoin(.miter)
        if let background {
            cg.setFillColor(background)
            cg.fill(CGRect(origin: .zero, size: size))
        } else {
            cg.clear(CGRect(origin: .zero, size: size))
        }

        if mode == .cross {
            ensureCameras(force: false)
            syncCrossCameras()
            updateCrossLineData()
            let cpCamera = cameras?.top
            let fmCamera = cameras?.bottom
            if let fmCamera {
                cg.saveGState()
                cg.clip(to: panelRect(.bottom))
                drawXray(cg, camera: fmCamera)
                drawCutLine(cg, camera: fmCamera, segments: crossLineData?.fmSegments)
                cg.restoreGState()
            }
            if let cpCamera {
                cg.saveGState()
                cg.clip(to: panelRect(.top))
                drawCrossCpPanel(cg, camera: cpCamera)
                cg.restoreGState()
            }
            drawDivider(cg)
            if let touch = effectiveTouchCircle {
                let cam = touch.panel == .top ? cpCamera : fmCamera
                if let cam { drawTouchCircle(cg, camera: cam, circle: touch) }
            }
            return
        }

        syncFullCamera()
        if mode == .overlap {
            if overlapEnabledFlag {
                ensureOverlapData()
                drawOverlap(cg, camera: camera)
            }
        } else {
            drawXray(cg, camera: camera)
        }
        if let touch = effectiveTouchCircle {
            drawTouchCircle(cg, camera: camera, circle: touch)
        }
    }

    // MARK: - X-Ray / wireframe drawing (GLRendererFoldCpXray)

    private func drawXray(_ cg: CGContext, camera: Camera) {
        guard let data = xrayGeometry else { return }
        let wire = wireframeFlag

        if !wire {
            // One path per face: overlapping faces accumulate the 5% alpha (GL blends every
            // triangle), but a face's own fan triangles are filled once so they do not
            // double-blend along shared edges. Batching all faces into one path would apply
            // the alpha once and make the view nearly invisible (see render-api.md).
            cg.saveGState()
            cg.setAlpha(Double(Constant.ALPHA_FOLD_CP_XRAY_FACE))
            cg.setFillColor(FoldColor.cg(ORIPACore.Color.COLOR_XRAY_FACE))
            for polygon in data.fmFaces where polygon.count >= 3 {
                let path = CGMutablePath()
                path.move(to: camera.objectToScreen(x: polygon[0].x, y: polygon[0].y))
                for p in polygon.dropFirst() {
                    path.addLine(to: camera.objectToScreen(x: p.x, y: p.y))
                }
                path.closeSubpath()
                cg.addPath(path)
                cg.fillPath()
            }
            cg.restoreGState()
        }

        // Crease lines (all segments in one path, like the Canvas-2D batch).
        if !data.fmCreases.isEmpty {
            cg.saveGState()
            cg.setAlpha(wire ? 1.0 : Double(Constant.ALPHA_FOLD_CP_XRAY_LINE_CREASE))
            cg.setStrokeColor(FoldColor.cg(wire ? ORIPACore.Color.COLOR_WIRE_CREASE
                                                : ORIPACore.Color.COLOR_XRAY_CREASE))
            cg.setLineWidth(FoldRenderStyle.foldCreaseWidth)
            cg.addPath(Self.path(for: data.fmCreases, camera: camera))
            cg.strokePath()
            cg.restoreGState()
        }

        // Boundary lines.
        if !data.fmBoundaries.isEmpty {
            cg.saveGState()
            cg.setAlpha(wire ? 1.0 : Double(Constant.ALPHA_FOLD_CP_XRAY_LINE_BOUNDARY))
            cg.setStrokeColor(FoldColor.cg(wire ? ORIPACore.Color.COLOR_WIRE_BOUNDARY
                                                : ORIPACore.Color.COLOR_XRAY_BOUNDARY))
            cg.setLineWidth(FoldRenderStyle.foldBoundaryWidth)
            cg.addPath(Self.path(for: data.fmBoundaries, camera: camera))
            cg.strokePath()
            cg.restoreGState()
        }
    }

    // MARK: - Cut Line CP panel (GLRendererFoldCpCross top half)

    private func drawCrossCpPanel(_ cg: CGContext, camera: Camera) {
        guard let data = xrayGeometry else { return }

        // Two-colour CP polygons: the screen-space winding picks front (#FFF4F7) / back (#E6F8FB).
        let frontColor = FoldColor.cg(FoldRenderer.CP_FACE_FRONT)
        let backColor = FoldColor.cg(FoldRenderer.CP_FACE_BACK)
        for triangle in data.cpTriangles {
            let a = camera.objectToScreen(x: triangle.a.x, y: triangle.a.y)
            let b = camera.objectToScreen(x: triangle.b.x, y: triangle.b.y)
            let c = camera.objectToScreen(x: triangle.c.x, y: triangle.c.y)
            let signed = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
            cg.setFillColor(signed < 0 ? frontColor : backColor)
            let path = CGMutablePath()
            path.move(to: a)
            path.addLine(to: b)
            path.addLine(to: c)
            path.closeSubpath()
            cg.addPath(path)
            cg.fillPath()
        }

        // Typed CP lines: draw each type as one path (the JS strokes one line at a time; a
        // per-type batch is visually identical because every line is opaque and 1 px wide).
        var paths: [Int: CGMutablePath] = [:]
        var i = 0
        let order = data.cpLineOrder
        while i + 1 < order.count {
            let slot = order[i]
            let endSlot = order[i + 1]
            i += 2
            guard slot >= 0, slot < data.cpPoints.count,
                  endSlot >= 0, endSlot < data.cpPoints.count,
                  slot < data.cpLineTypes.count else { continue }
            let type = data.cpLineTypes[slot]
            let path = paths[type] ?? CGMutablePath()
            paths[type] = path
            let p0 = data.cpPoints[slot]
            let p1 = data.cpPoints[endSlot]
            path.move(to: camera.objectToScreen(x: p0.x, y: p0.y))
            path.addLine(to: camera.objectToScreen(x: p1.x, y: p1.y))
        }
        cg.setLineWidth(FoldRenderStyle.cpLineWidth)
        for type in paths.keys.sorted() {
            guard let rgb = LineType.getColor(type), let path = paths[type] else { continue }
            cg.setStrokeColor(FoldColor.cg(rgb))
            cg.addPath(path)
            cg.strokePath()
        }

        drawCutLine(cg, camera: camera, segments: crossLineData?.cpSegments)
    }

    // MARK: - Magenta cut / slice line

    private func drawCutLine(_ cg: CGContext, camera: Camera, segments: [FoldSegment]?) {
        guard let segments, !segments.isEmpty else { return }
        cg.saveGState()
        cg.setStrokeColor(FoldColor.cg(ORIPACore.Color.COLOR_SLICE))
        cg.setLineWidth(crossLineActiveFlag ? FoldRenderStyle.crossLineWidthActive
                                            : FoldRenderStyle.crossLineWidth)
        cg.addPath(Self.path(for: segments, camera: camera))
        cg.strokePath()
        cg.restoreGState()
    }

    // MARK: - Overlap drawing (GLRendererFoldCpOverlap)

    private func drawOverlap(_ cg: CGContext, camera: Camera) {
        guard let sets = overlapSetsData else { return }
        let flip = options.flip ?? preferences.flip
        let frontColor = FoldColor.cg(argb: options.frontColor ?? preferences.frontColor)
        let backColor = FoldColor.cg(argb: options.backColor ?? preferences.backColor)
        let lineColor = FoldColor.cg(argb: options.lineColor ?? preferences.lineColor)
        let halfWidth = FoldRenderStyle.overlapLineHalfWidth
        let shadowWidth = FoldRenderStyle.overlapShadowWidth
        let shadowAlpha = FoldRenderStyle.overlapShadowAlpha
        let rotationDeg = camera.rotationDeg

        func offset(for type: Int) -> CGFloat {
            if type == 2 { return halfWidth }
            if type == 4 { return shadowWidth }
            return 0
        }

        func place(_ p: CGPoint, angleDegTenths: CGFloat, offset: CGFloat) -> CGPoint {
            let s = camera.objectToScreen(x: p.x, y: p.y)
            guard offset != 0 else { return s }
            let radians = (Double(angleDegTenths) / 10.0 + Double(rotationDeg)) * .pi / 180.0
            return CGPoint(x: s.x + offset * CGFloat(cos(radians)),
                           y: s.y + offset * CGFloat(sin(radians)))
        }

        for set in sets {
            let side = flip ? set.reverse : set.front
            guard !side.order.isEmpty else { continue }
            var i = 0
            while i + 2 < side.order.count {
                let i0 = side.order[i]
                let i1 = side.order[i + 1]
                let i2 = side.order[i + 2]
                i += 3
                guard i0 >= 0, i1 >= 0, i2 >= 0,
                      i0 < side.types.count, i1 < side.types.count, i2 < side.types.count,
                      i0 < side.points.count, i1 < side.points.count, i2 < side.points.count,
                      i0 < side.angles.count, i1 < side.angles.count, i2 < side.angles.count else { continue }
                let t0 = side.types[i0]
                let t1 = side.types[i1]
                let t2 = side.types[i2]
                let isShadow = !(t0 == 0 || t0 == 1 || t0 == 2)
                let p0 = place(side.points[i0], angleDegTenths: side.angles[i0], offset: offset(for: t0))
                let p1 = place(side.points[i1], angleDegTenths: side.angles[i1], offset: offset(for: t1))
                let p2 = place(side.points[i2], angleDegTenths: side.angles[i2], offset: offset(for: t2))
                let path = CGMutablePath()
                path.move(to: p0)
                path.addLine(to: p1)
                path.addLine(to: p2)
                path.closeSubpath()

                if isShadow {
                    // Fade from black 38% at the outline to transparent at the outer ring.
                    var inner = p0
                    var outerA = p1
                    var outerB = p2
                    if t0 == 3 {
                        inner = p0; outerA = p1; outerB = p2
                    } else if t1 == 3 {
                        inner = p1; outerA = p0; outerB = p2
                    } else {
                        inner = p2; outerA = p0; outerB = p1
                    }
                    let mid = CGPoint(x: (outerA.x + outerB.x) / 2.0, y: (outerA.y + outerB.y) / 2.0)
                    let colors = [
                        CGColor(srgbRed: 0, green: 0, blue: 0, alpha: shadowAlpha),
                        CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0),
                    ] as CFArray
                    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                 colors: colors,
                                                 locations: [0, 1]) {
                        cg.saveGState()
                        cg.addPath(path)
                        cg.clip()
                        cg.drawLinearGradient(gradient, start: inner, end: mid, options: [])
                        cg.restoreGState()
                    }
                } else {
                    if t0 == 2 {
                        cg.setFillColor(lineColor)
                    } else if t0 == 0 {
                        cg.setFillColor(frontColor)
                    } else {
                        cg.setFillColor(backColor)
                    }
                    cg.addPath(path)
                    cg.fillPath()
                }
            }
        }
    }

    // MARK: - Viewport divider

    private func drawDivider(_ cg: CGContext) {
        cg.saveGState()
        cg.setStrokeColor(FoldColor.cg(ORIPACore.Color.COLOR_GRID))
        cg.setLineWidth(FoldRenderStyle.viewportDividerWidth)
        let path = CGMutablePath()
        if cssW <= cssH {
            path.move(to: CGPoint(x: 0, y: cssH / 2))
            path.addLine(to: CGPoint(x: cssW, y: cssH / 2))
        } else {
            path.move(to: CGPoint(x: cssW / 2, y: 0))
            path.addLine(to: CGPoint(x: cssW / 2, y: cssH))
        }
        cg.addPath(path)
        cg.strokePath()
        cg.restoreGState()
    }

    // MARK: - Touch circle

    private func drawTouchCircle(_ cg: CGContext, camera: Camera, circle: FoldTouchCircle) {
        if mode == .cross, let cameras {
            let wanted = circle.panel == .top ? cameras.top : cameras.bottom
            if wanted !== camera { return }
        }
        let center = camera.objectToScreen(x: circle.x, y: circle.y)
        let edge = camera.objectToScreen(x: circle.x + circle.radius, y: circle.y)
        let radius = abs(edge.x - center.x)
        guard radius > 0 else { return }
        cg.saveGState()
        cg.setAlpha(FoldRenderStyle.touchCircleAlpha)
        cg.setFillColor(FoldColor.cg(ORIPACore.Color.COLOR_TOUCH_CIRCLE))
        cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                  width: radius * 2, height: radius * 2))
        cg.restoreGState()
    }

    // MARK: - Small helpers

    private static func path(for segments: [FoldSegment], camera: Camera) -> CGPath {
        let path = CGMutablePath()
        for segment in segments {
            path.move(to: camera.objectToScreen(x: segment.a.x, y: segment.a.y))
            path.addLine(to: camera.objectToScreen(x: segment.b.x, y: segment.b.y))
        }
        return path
    }
}

// MARK: - Internal geometry (converted from the GLDataFm* render data)

/// A line segment in object space.
private struct FoldSegment {
    var a: CGPoint
    var b: CGPoint
}

/// Screen-space triangle index triple.
private struct FoldTriangle {
    var a: CGPoint
    var b: CGPoint
    var c: CGPoint
}

/// Geometry shared by the x-ray view and the Cut Line split view (`GLDataFmXrayCross`).
private struct FoldXrayGeometry {
    /// Folded-model faces (one closed polygon per face) for the x-ray alpha accumulation.
    var fmFaces: [[CGPoint]] = []
    var fmCreases: [FoldSegment] = []
    var fmBoundaries: [FoldSegment] = []
    /// CP panel: 3 copies of every vertex (slot = vertex*3 + (type-1)); the polygon draw
    /// order uses the first copy of every vertex, the line draw order the typed copy.
    var cpPoints: [CGPoint] = []
    var cpLineTypes: [Int] = []
    var cpLineOrder: [Int] = []
    var cpTriangles: [FoldTriangle] = []

    init() {}

    init(raw: GLDataFmXrayCross, fm: FoldedModel) {
        let fmPoints = FoldGeometry.points(raw.fmPointPosition)
        func point(_ index: Int) -> CGPoint {
            guard index >= 0, index < fmPoints.count else { return .zero }
            return fmPoints[index]
        }
        var i = 0
        while i + 1 < raw.fmCreaseLineDrawOrder.count {
            fmCreases.append(FoldSegment(a: point(raw.fmCreaseLineDrawOrder[i]),
                                         b: point(raw.fmCreaseLineDrawOrder[i + 1])))
            i += 2
        }
        i = 0
        while i + 1 < raw.fmBoundaryLineDrawOrder.count {
            fmBoundaries.append(FoldSegment(a: point(raw.fmBoundaryLineDrawOrder[i]),
                                            b: point(raw.fmBoundaryLineDrawOrder[i + 1])))
            i += 2
        }

        cpPoints = FoldGeometry.points(raw.cpPointPosition)
        cpLineTypes = raw.cpLineType.map { Int($0) }
        cpLineOrder = raw.cpLineDrawOrder
        i = 0
        while i + 2 < raw.cpPolygonDrawOrder.count {
            let ia = raw.cpPolygonDrawOrder[i]
            let ib = raw.cpPolygonDrawOrder[i + 1]
            let ic = raw.cpPolygonDrawOrder[i + 2]
            i += 3
            guard ia >= 0, ib >= 0, ic >= 0,
                  ia < cpPoints.count, ib < cpPoints.count, ic < cpPoints.count else { continue }
            cpTriangles.append(FoldTriangle(a: cpPoints[ia], b: cpPoints[ib], c: cpPoints[ic]))
        }

        if !fm.mFaces.isEmpty {
            // JS: closed outline = start(0), end(0), end(1), ... end(n-1) (the last end
            // repeats the first start; closePath handles it).
            for face in fm.mFaces {
                let edges = face.halfEdges
                guard edges.count >= 3, let first = edges.first else { continue }
                var polygon: [CGPoint] = []
                polygon.reserveCapacity(edges.count + 1)
                polygon.append(FoldGeometry.folded(first.start))
                for edge in edges { polygon.append(FoldGeometry.folded(edge.end)) }
                fmFaces.append(polygon)
            }
        } else {
            // Fallback: the render data's triangle fan (JS `else` branch).
            var i = 0
            while i + 2 < raw.fmFaceDrawOrder.count {
                let a = point(raw.fmFaceDrawOrder[i])
                let b = point(raw.fmFaceDrawOrder[i + 1])
                let c = point(raw.fmFaceDrawOrder[i + 2])
                i += 3
                fmFaces.append([a, b, c])
            }
        }
    }
}

/// One side of the overlap render data (`GLDataFmOverlap`).
private struct FoldOverlapSide {
    var points: [CGPoint] = []
    var types: [Int] = []
    /// Tenths of a degree (`short` in the Java encoding).
    var angles: [CGFloat] = []
    var order: [Int] = []

    init() {}

    init(rawPoints: [Float], rawTypes: [UInt8], rawAngles: [Float], rawOrder: [Int]) {
        points = FoldGeometry.points(rawPoints)
        types = rawTypes.map { Int($0) }
        angles = rawAngles.map { CGFloat($0) }
        order = rawOrder
    }
}

/// Front + reversed ('two-colour') overlap sets (`GLDataFmOverlap`).
private struct FoldOverlapSet {
    var front = FoldOverlapSide()
    var reverse = FoldOverlapSide()

    init(raw: GLDataFmOverlap) {
        front = FoldOverlapSide(rawPoints: raw.pointPosition,
                                rawTypes: raw.pointType,
                                rawAngles: raw.pointAngleDeg,
                                rawOrder: raw.drawOrder)
        reverse = FoldOverlapSide(rawPoints: raw.reversePointPosition,
                                  rawTypes: raw.reversePointType,
                                  rawAngles: raw.reversePointAngleDeg,
                                  rawOrder: raw.reverseDrawOrder)
    }
}

/// Cut-line segments in FM and CP coordinates (`GLDataFmCrossLine`).
private struct FoldCrossLineData {
    var fmSegments: [FoldSegment] = []
    var cpSegments: [FoldSegment] = []

    init(cpPosition: [Float], fmPosition: [Float]) {
        fmSegments = FoldGeometry.segments(fmPosition)
        cpSegments = FoldGeometry.segments(cpPosition)
    }
}

// MARK: - Value conversion helpers

private enum FoldGeometry {
    static func points(_ flat: [Float]) -> [CGPoint] {
        var result: [CGPoint] = []
        result.reserveCapacity(flat.count / 2)
        var i = 0
        while i + 1 < flat.count {
            result.append(CGPoint(x: CGFloat(flat[i]), y: CGFloat(flat[i + 1])))
            i += 2
        }
        return result
    }

    static func segments(_ flat: [Float]) -> [FoldSegment] {
        var result: [FoldSegment] = []
        result.reserveCapacity(flat.count / 4)
        var i = 0
        while i + 3 < flat.count {
            result.append(FoldSegment(a: CGPoint(x: CGFloat(flat[i]), y: CGFloat(flat[i + 1])),
                                      b: CGPoint(x: CGFloat(flat[i + 2]), y: CGFloat(flat[i + 3]))))
            i += 4
        }
        return result
    }

    /// Folded vertex position (`valueAfterFold`); falls back to the CP coordinates for a
    /// vertex that was never folded (only reachable through a defensive render).
    static func folded(_ vertex: OriVertex) -> CGPoint {
        if let p = vertex.valueAfterFold {
            return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        }
        return CGPoint(x: CGFloat(vertex.x), y: CGFloat(vertex.y))
    }
}

// MARK: - Colour conversion

private enum FoldColor {
    static func cg(_ rgb: RGB, opacity: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(rgb.r),
                green: CGFloat(rgb.g),
                blue: CGFloat(rgb.b),
                alpha: opacity)
    }

    /// Android `0xAARRGGBB` colour int -> CGColor (mirrors `RenderUtil.argbCss`).
    static func cg(argb: UInt32) -> CGColor {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
