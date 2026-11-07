// Fold CP screen model — port of the state/behaviour half of
// `oripa-port/src/js/ui/fragments/fold.js` (`FoldCpFragment` + the three
// GLSurfaceViewFoldCp* touch behaviours). The SwiftUI views live in `FoldScreen.swift`
// and `FoldChrome.swift`; this class owns the fold model plumbing, the per-mode
// renderers/cameras, the gesture math and the settings/export dialog state.
//
// Fragment lifecycle (Android `FoldCpFragment` is re-created on every fold entry, while
// the web editor keeps the fragment alive):
//   * `enter(size:)` rebuilds renderers/cameras and resets the spinner to item 0 after the
//     screen was left (`pendingViewReset`), exactly like `fold.js` `enter()`.
//   * `leave()` drops the renderers (Java `onDestroyView`) and marks the reset pending.
import SwiftUI
import ORIPACore

/// Which settings dialog is open (port of the three Android DialogFragments).
enum FoldSettingsSheet {
    case xray(initialWireframe: Bool)
    case overlap(flip: Bool, front: UInt32, back: UInt32, line: UInt32)
    case crossLine(initialAngleDeg: Int,
                   initialPosition: Int,
                   initialButtonVisible: Bool,
                   angleDegMax: Int,
                   positionMax: Int,
                   wireframeInitial: Bool)
}

/// Fold export dialog steps (`fold_export.js` flow).
enum FoldExportSheet {
    case fileType
    case pngOptions(defaultSize: Int)
}

@MainActor
final class FoldViewModel: ObservableObject {

    // MARK: - Session / services

    let session: any EditorSessionProtocol
    let app: AppModel

    var cp: CreasePattern { session.cp }
    var fm: FoldedModel { session.foldedModel }
    var clm: CrossLineManager { session.crossLineManager }
    var prefs: Preferences { session.prefs }

    // MARK: - Published UI state

    /// Spinner index: 0 xray, 1 overlap, 2 cross.
    @Published private(set) var modeIndex: Int = 0
    /// Renderer of the visible mode (the SwiftUI canvas observes it for redraws).
    @Published private(set) var activeRenderer: FoldRenderer?
    /// `cross_button_container` visibility (Cut Line mode only).
    @Published private(set) var crossButtonsVisible = false
    /// `FoldCpFragment.crossOneFingerMove` (Cut Line move / rotate preference).
    @Published private(set) var crossOneFingerMove = true
    /// `FoldCpFragment.xrayStyleWire` (wireframe mode).
    @Published private(set) var wireframe = false
    /// Open settings dialog (X-Ray / Overlap / Cut Line).
    @Published var settingsSheet: FoldSettingsSheet?
    /// Open export dialog (file type / PNG size).
    @Published var exportSheet: FoldExportSheet?
    /// Title spinner popup menu.
    @Published var showsModeMenu = false
    /// Canvas size in points (assigned by `enter`/`resize`).
    @Published private(set) var canvasSize: CGSize = .zero

    // MARK: - Renderers / cameras

    private var renderers: [FoldRenderer?] = [nil, nil, nil]
    private var cameraXray = Camera()
    private var cameraOverlap = Camera()
    private var crossCameras: FoldCameraPair?
    private var pendingViewReset = false

    // MARK: - Gesture state

    private struct PinchState {
        var lastScale: CGFloat = 1
        var lastAngle: CGFloat = 0
        var cx: CGFloat = 0
        var cy: CGFloat = 0
        var camera: Camera?
    }

    private var pinch = PinchState()

    private struct CrossDragState {
        var initialAngleDeg: Int
        var initialPosition: Int
        var initialPoint: CGPoint
        var angleDeg: Int
        var position: Int
    }

    private var crossDrag: CrossDragState?
    private var crossLineDragging = false
    /// Snapshot QA hook: the spinner item a freshly created screen starts on (production = 0).
    private let initialModeIndex: Int
    private var hasEnteredOnce = false

    // Cut Line settings dialog restore values (Java onCancel).
    private var settingsInitialCrossAngle = 0
    private var settingsInitialCrossPosition = 0
    private var settingsInitialButtonsVisible = false

    // MARK: - Init

    init(session: any EditorSessionProtocol, app: AppModel, initialModeIndex: Int = 0) {
        self.session = session
        self.app = app
        self.initialModeIndex = min(max(0, initialModeIndex), FoldMode.allCases.count - 1)
        cameraXray.reset()
        cameraOverlap.reset()
    }

    // MARK: - Derived preferences

    var mode: FoldMode { FoldMode(spinnerIndex: modeIndex) ?? .xray }

    var overlapFrontColor: UInt32 {
        FoldOverlapDefaults.color(fromPref: prefs.int(FoldPref.overlapFrontColor,
                                                     default: FoldOverlapDefaults.frontColorPref))
    }

    var overlapBackColor: UInt32 {
        FoldOverlapDefaults.color(fromPref: prefs.int(FoldPref.overlapBackColor,
                                                     default: FoldOverlapDefaults.backColorPref))
    }

    var overlapLineColor: UInt32 {
        FoldOverlapDefaults.color(fromPref: prefs.int(FoldPref.overlapLineColor,
                                                     default: FoldOverlapDefaults.lineColorPref))
    }

    var overlapFlip: Bool {
        prefs.bool(FoldPref.overlapFlip, default: FoldOverlapDefaults.flip)
    }

    var overlapEnabled: Bool {
        prefs.bool(FoldPref.overlapEnabled, default: true)
    }

    var overlapShadow: Bool {
        prefs.bool(FoldPref.overlapShadow, default: false)
    }

    /// `rendererPreferences()` in fold.js.
    var rendererPreferences: FoldRenderPreferences {
        FoldRenderPreferences(wireframe: wireframe,
                              overlapEnabled: overlapEnabled,
                              overlapShadow: overlapShadow,
                              flip: overlapFlip,
                              frontColor: overlapFrontColor,
                              backColor: overlapBackColor,
                              lineColor: overlapLineColor)
    }

    /// `rendererOptions()` in fold.js.
    func rendererOptions() -> FoldRenderOptions {
        var options = FoldRenderOptions()
        options.wireframe = wireframe
        options.flip = overlapFlip
        options.frontColor = overlapFrontColor
        options.backColor = overlapBackColor
        options.lineColor = overlapLineColor
        options.overlapShadow = overlapShadow
        options.overlapEnabled = overlapEnabled
        options.crossPosition = clm.getCurrentCrossLinePosition()
        options.crossAngleDeg = clm.getCurrentCrossLineAngleDeg()
        options.showCrossButtons = crossButtonsVisible
        return options
    }

    /// `crossLineMaxima()` in fold.js.
    var crossLineMaxima: (angleDegMax: Int, positionMax: Int, positionMin: Int) {
        (fm.crossLine.getAngleDegMaxMagnitude(),
         fm.crossLine.getPositionMaxMagnitude(),
         fm.crossLine.getPositionMinMagnitude())
    }

    // MARK: - Folded model / lifecycle

    /// `ensureFoldedModel()`: the editor normally folds before mounting the fold screen;
    /// fold defensively (and build the cross-line render data) when it did not.
    private func ensureFoldedModel() {
        if fm.mFaces.isEmpty {
            fm.foldWithoutOverlap(cp)
            if overlapEnabled { fm.foldWithOverlap() }
        }
        if clm.getCrossLineRenderData() == nil && !fm.mFaces.isEmpty {
            clm.getNew(fm)
        }
    }

    /// Fragment `enter()`: build the fold view for the current mode, restarting from the
    /// Android initial state after the screen was left.
    func enter(size: CGSize) {
        canvasSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        ensureFoldedModel()
        wireframe = prefs.bool(FoldPref.xrayStyleWire, default: false)
        crossOneFingerMove = prefs.bool(FoldPref.crossOneFingerMove, default: true)
        if pendingViewReset || !hasEnteredOnce {
            pendingViewReset = false
            modeIndex = initialModeIndex
            renderers = [nil, nil, nil]
            activeRenderer = nil
            cameraXray = Camera()
            cameraOverlap = Camera()
            crossCameras = nil
            crossLineDragging = false
            crossDrag = nil
            pinch = PinchState()
            settingsSheet = nil
            exportSheet = nil
            showsModeMenu = false
        }
        hasEnteredOnce = true
        applyMode(modeIndex)
    }

    /// Fragment `leave()`: Java drops the GL views + fold model references on destroy.
    func leave() {
        pendingViewReset = true
        endCrossLineDrag()
        renderers = [nil, nil, nil]
        activeRenderer = nil
        crossCameras = nil
        settingsSheet = nil
        exportSheet = nil
        showsModeMenu = false
    }

    /// Canvas size changed (`onResize`).
    func resize(_ size: CGSize) {
        let newSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        guard abs(newSize.width - canvasSize.width) > 0.5
            || abs(newSize.height - canvasSize.height) > 0.5 else { return }
        canvasSize = newSize
        resizeRenderers()
        activeRenderer?.requestDraw()
    }

    private func resizeRenderers() {
        let width = canvasSize.width
        let height = canvasSize.height
        guard width > 0, height > 0 else { return }
        for index in 0..<renderers.count {
            guard let renderer = renderers[index] else { continue }
            renderer.resize(width, height)
            if FoldMode(spinnerIndex: index) == .cross, let pair = renderer.cameras {
                crossCameras = pair
            }
        }
    }

    // MARK: - Mode switching (FoldCpFragment.updateGLView)

    func selectMode(_ index: Int) {
        showsModeMenu = false
        guard index != modeIndex || activeRenderer == nil else { return }
        applyMode(index)
    }

    private func applyMode(_ index: Int) {
        guard let newMode = FoldMode(spinnerIndex: index) else { return }
        if newMode != .cross || modeIndex != index { endCrossLineDrag() }
        modeIndex = index
        crossButtonsVisible = (newMode == .cross)
        if newMode == .cross {
            crossOneFingerMove = prefs.bool(FoldPref.crossOneFingerMove, default: true)
        }
        ensureRenderer(index)
        resizeRenderers()
        activeRenderer?.requestDraw()
    }

    /// `ensureRenderer(index)`: one FoldRenderer per spinner item, created lazily.
    @discardableResult
    private func ensureRenderer(_ index: Int) -> FoldRenderer? {
        if let existing = renderers[index] {
            activeRenderer = existing
            return existing
        }
        guard let mode = FoldMode(spinnerIndex: index) else { return nil }
        let renderer = FoldRenderer()
        renderer.setMode(mode)
        renderer.setCreasePattern(cp)
        renderer.setFoldedModel(fm)
        renderer.setCrossLineManager(clm)
        renderer.setPreferences(rendererPreferences)
        renderer.setOptions(rendererOptions())
        renderers[index] = renderer
        renderer.resize(canvasSize.width, canvasSize.height)
        if mode == .cross {
            // Adopt the renderer's default cameras (Android initial CP-panel fit + S(0.5)).
            if let pair = renderer.cameras { crossCameras = pair }
        } else {
            renderer.setCamera(mode == .xray ? cameraXray : cameraOverlap)
        }
        renderer.requestDraw()
        activeRenderer = renderer
        return renderer
    }

    /// `refreshRenderers(redrawAll)`.
    private func refreshRenderers(redrawAll: Bool) {
        for index in 0..<renderers.count {
            guard let renderer = renderers[index] else { continue }
            renderer.setPreferences(rendererPreferences)
            renderer.setOptions(rendererOptions())
            if FoldMode(spinnerIndex: index) == .cross,
               let pair = crossCameras,
               let current = renderer.cameras,
               current.top !== pair.top || current.bottom !== pair.bottom {
                renderer.setCameras(pair)
            }
            if redrawAll || index == modeIndex { renderer.requestDraw() }
        }
    }

    // MARK: - Cut line state (applyCrossLine / applyWireframe)

    /// `applyCrossLine(angleDeg, position)`: the render data + the renderer options; every
    /// change goes through the CrossLineManager (Java GLSurfaceViewFoldCpCross.onScroll).
    func applyCrossLine(angleDeg: Int, position: Int) {
        clm.updateCrossLineRenderData(fm, angleDeg: angleDeg, position: position)
        let crossRenderer = renderers[2]
        crossRenderer?.setOptions(rendererOptions())
        if modeIndex == 2 { crossRenderer?.requestDraw() }
    }

    /// `applyWireframe(enabled)`: wireframe applies to x-ray + cross only (Java).
    func applyWireframe(_ enabled: Bool) {
        wireframe = enabled
        for index in 0..<renderers.count {
            if FoldMode(spinnerIndex: index) == .overlap { continue }
            guard let renderer = renderers[index] else { continue }
            renderer.setOptions(rendererOptions())
            if index == modeIndex { renderer.requestDraw() }
        }
    }

    // MARK: - Cut-line move / rotate mini buttons

    func setCrossOneFingerMove(_ move: Bool) {
        crossOneFingerMove = move
        prefs.setBool(move, for: FoldPref.crossOneFingerMove)
    }

    // MARK: - Settings dialogs

    func openSettings() {
        switch mode {
        case .xray:
            settingsSheet = .xray(initialWireframe: wireframe)
        case .overlap:
            settingsSheet = .overlap(flip: overlapFlip,
                                     front: overlapFrontColor,
                                     back: overlapBackColor,
                                     line: overlapLineColor)
        case .cross:
            settingsInitialCrossAngle = clm.getCurrentCrossLineAngleDeg()
            settingsInitialCrossPosition = clm.getCurrentCrossLinePosition()
            settingsInitialButtonsVisible = crossButtonsVisible
            let maxima = crossLineMaxima
            settingsSheet = .crossLine(initialAngleDeg: settingsInitialCrossAngle,
                                       initialPosition: settingsInitialCrossPosition,
                                       initialButtonVisible: settingsInitialButtonsVisible,
                                       angleDegMax: maxima.angleDegMax,
                                       positionMax: maxima.positionMax,
                                       wireframeInitial: wireframe)
        }
    }

    func closeSettings() {
        settingsSheet = nil
    }

    /// X-Ray dialog: each tap persists `FoldCpFragment.xrayStyleWire` + redraws.
    func xraySettingsWireframeChanged(_ enabled: Bool) {
        prefs.setBool(enabled, for: FoldPref.xrayStyleWire)
        applyWireframe(enabled)
    }

    /// Overlap dialog: flip persists immediately + redraws.
    func overlapSettingsFlipChanged(_ flip: Bool) {
        prefs.setBool(flip, for: FoldPref.overlapFlip)
        refreshRenderers(redrawAll: false)
        activeRenderer?.requestDraw()
    }

    /// Overlap dialog: pick a colour, persist the Android int and redraw.
    func overlapSettingsColorsChanged(front: UInt32, back: UInt32, line: UInt32) {
        prefs.setInt(FoldOverlapDefaults.prefInt(fromColor: front), for: FoldPref.overlapFrontColor)
        prefs.setInt(FoldOverlapDefaults.prefInt(fromColor: back), for: FoldPref.overlapBackColor)
        prefs.setInt(FoldOverlapDefaults.prefInt(fromColor: line), for: FoldPref.overlapLineColor)
        refreshRenderers(redrawAll: false)
        activeRenderer?.requestDraw()
    }

    /// Cut Line dialog: live seekbar preview.
    func crossLineSettingsUpdated(angleDeg: Int, position: Int) {
        applyCrossLine(angleDeg: angleDeg, position: position)
    }

    /// Cut Line dialog: live wireframe checkbox.
    func crossLineSettingsWireframeChanged(_ enabled: Bool) {
        applyWireframe(enabled)
    }

    /// Cut Line dialog: live show-buttons checkbox.
    func crossLineSettingsButtonsVisibleChanged(_ visible: Bool) {
        crossButtonsVisible = visible
    }

    /// Cut Line dialog OK: persist the wireframe pref, apply everything, close.
    func crossLineSettingsConfirmed(angleDeg: Int, position: Int, wireframeEnabled: Bool) {
        prefs.setBool(wireframeEnabled, for: FoldPref.xrayStyleWire)
        wireframe = wireframeEnabled
        applyCrossLine(angleDeg: angleDeg, position: position)
        applyWireframe(wireframeEnabled)
        refreshRenderers(redrawAll: false)
        settingsSheet = nil
    }

    /// Cut Line dialog Cancel: restore the initial angle/position, persisted wireframe and
    /// button visibility (Java `onCancel`).
    func crossLineSettingsCancelled() {
        applyCrossLine(angleDeg: settingsInitialCrossAngle, position: settingsInitialCrossPosition)
        applyWireframe(prefs.bool(FoldPref.xrayStyleWire, default: false))
        crossButtonsVisible = settingsInitialButtonsVisible
        settingsSheet = nil
    }

    // MARK: - Export flow (fold_export.js)

    func openExport() {
        exportSheet = .fileType
    }

    func closeExport() {
        exportSheet = nil
    }

    /// `ExportExternalDialogFragment` selection: every mode offers SVG + PNG.
    func selectExportFileType(_ fileType: FileType) {
        switch fileType {
        case .png:
            exportSheet = .pngOptions(defaultSize: 1000)
        case .svg:
            exportSheet = nil
            exportSVG()
        default:
            break
        }
    }

    /// `ExportPngSquareDialogFragment` OK: `size` for x-ray/overlap, `2*size` width for cross
    /// (Java `getFoldedModelCross(i*2, i)`).
    func exportPNG(size: Int) {
        exportSheet = nil
        let exportMode = mode
        let width = exportMode == .cross ? size * 2 : size
        let options = FoldPNGExport.Options(
            wireframe: wireframe,
            flip: overlapFlip,
            frontColor: overlapFrontColor,
            backColor: overlapBackColor,
            lineColor: overlapLineColor,
            overlapShadow: overlapShadow,
            overlapEnabled: overlapEnabled,
            cp: cp,
            crossLineManager: clm,
            crossPosition: clm.getCurrentCrossLinePosition(),
            crossAngleDeg: clm.getCurrentCrossLineAngleDeg(),
            background: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        guard let data = FoldPNGExport.render(fm: fm,
                                              mode: exportMode,
                                              width: width,
                                              height: size,
                                              options: options) else {
            snackbarFail()
            return
        }
        exportData(data, fileType: .png)
    }

    /// `getExportSvg`: overlap uses the overlap exporter, x-ray and cross export the x-ray
    /// SVG (Java quirk kept).
    func exportSVG() {
        let options = FoldedModelSvgOptions(
            wire: wireframe,
            flip: overlapFlip,
            frontColor: FoldOverlapDefaults.prefInt(fromColor: overlapFrontColor),
            backColor: FoldOverlapDefaults.prefInt(fromColor: overlapBackColor),
            lineColor: FoldOverlapDefaults.prefInt(fromColor: overlapLineColor))
        let svg = OripaIO.exportFoldedModelSvg(fm, mode: mode.spinnerIndex, options: options)
        exportData(Data(svg.utf8), fileType: .svg)
    }

    private func exportData(_ data: Data, fileType: FileType) {
        let filename = "\(session.srcFilenameNoExt).\(fileType.getExtension())"
        app.fileExchange.export(data,
                                filename: filename,
                                mimeType: fileType.getMimeType()) { [weak self] exported in
            guard let self, exported else { return }
            self.app.toast.show(FoldStrings.downloadCompleteText)
        }
    }

    private func snackbarFail() {
        app.toast.show(FoldStrings.downloadFailedText)
    }

    // MARK: - Panel hit testing

    func hitPanel(_ point: CGPoint) -> FoldPanel {
        if let renderer = activeRenderer {
            return renderer.hitPanel(x: point.x, y: point.y)
        }
        if canvasSize.width <= canvasSize.height {
            return point.y < canvasSize.height / 2 ? .top : .bottom
        }
        return point.x >= canvasSize.width / 2 ? .top : .bottom
    }

    private func activeCamera(for point: CGPoint) -> Camera? {
        if mode != .cross { return mode == .xray ? cameraXray : cameraOverlap }
        guard let pair = crossCameras else { return nil }
        return hitPanel(point) == .top ? pair.top : pair.bottom
    }

    // MARK: - Gestures (AbstractGLSurfaceView / AbstractDoubleGLSurfaceView)

    /// `onTwoFingerStart`: pinch/pan/rotate begins (per panel in the Cut Line view).
    func twoFingerStart(at center: CGPoint) {
        pinch.lastScale = 1
        pinch.lastAngle = 0
        pinch.cx = center.x
        pinch.cy = center.y
        pinch.camera = activeCamera(for: center)
        if crossLineDragging { endCrossLineDrag() }
    }

    /// `onTwoFingerMove`: applies pan / pinch / rotate deltas to the active camera.
    func twoFingerMove(_ state: FoldTwoFingerState) {
        guard let camera = pinch.camera else { return }
        let dx = state.center.x - pinch.cx
        let dy = state.center.y - pinch.cy
        if dx != 0 || dy != 0 { camera.panBy(dx: dx, dy: dy) }
        let factor = pinch.lastScale > 0 ? state.scale / pinch.lastScale : 1
        if abs(factor - 1) > 1e-6 {
            _ = camera.zoomAt(factor: factor, focusX: state.center.x, focusY: state.center.y)
        }
        // Java: only X-Ray and Overlap call enableTouchRotate(); Cut Line pans/zooms only.
        if mode != .cross {
            let deg = (state.rotationRadians - pinch.lastAngle) * 180.0 / .pi
            if abs(deg) > 1e-6 {
                camera.rotateAt(deg: deg, centerX: state.center.x, centerY: state.center.y)
            }
        }
        pinch.lastScale = state.scale
        pinch.lastAngle = state.rotationRadians
        pinch.cx = state.center.x
        pinch.cy = state.center.y
        activeRenderer?.requestDraw()
    }

    func twoFingerEnd() {
        pinch.camera = nil
    }

    /// One-finger drag start (Cut Line: GLSurfaceViewFoldCpCross.onScroll).
    func dragStart(at point: CGPoint) {
        crossDrag = nil
        guard mode == .cross, hitPanel(point) == .bottom else { return }
        guard let pair = crossCameras else { return }
        let camera = pair.bottom
        let objectPoint = camera.screenToObject(x: point.x, y: point.y)
        let angle = clm.getCurrentCrossLineAngleDeg()
        let position = clm.getCurrentCrossLinePosition()
        crossDrag = CrossDragState(initialAngleDeg: angle,
                                   initialPosition: position,
                                   initialPoint: objectPoint,
                                   angleDeg: angle,
                                   position: position)
        crossLineDragging = true
        setCrossLineActive(true)
    }

    /// One-finger drag: move the cut line position or rotate its angle (pref-selected).
    func drag(to point: CGPoint) {
        guard var drag = crossDrag, let pair = crossCameras else { return }
        let camera = pair.bottom
        let objectPoint = camera.screenToObject(x: point.x, y: point.y)
        let dx = objectPoint.x - drag.initialPoint.x
        let dy = objectPoint.y - drag.initialPoint.y
        let maxima = crossLineMaxima
        if crossOneFingerMove {
            // Position mode: project the drag onto the axis perpendicular to the cut line.
            let distance = (dx * dx + dy * dy).squareRoot()
            let dragAngle = atan2(dy, dx)
            let deltaAngle = dragAngle - ((CGFloat(drag.initialAngleDeg) + 90) * .pi / 180.0)
            let candidate = CGFloat(drag.initialPosition) + (distance * cos(deltaAngle)).rounded(.towardZero)
            let newPosition = max(CGFloat(maxima.positionMin),
                                  min(CGFloat(maxima.positionMax), candidate))
            drag.position = Int(newPosition.rounded(.towardZero))
        } else {
            // Angle mode: rotate by the swept angle around the object origin.
            let sweep = atan2(objectPoint.y, objectPoint.x)
                - atan2(drag.initialPoint.y, drag.initialPoint.x)
            let delta = (sweep * 180.0 / .pi).rounded(.towardZero)
            drag.angleDeg = FoldMath.wrapClamp(drag.initialAngleDeg + Int(delta), maxima.angleDegMax)
        }
        crossDrag = drag
        setTouchCircle(objectPoint)
        applyCrossLine(angleDeg: drag.angleDeg, position: drag.position)
    }

    func dragEnd() {
        endCrossLineDrag()
    }

    func gestureCancelled() {
        endCrossLineDrag()
    }

    private func endCrossLineDrag() {
        if crossLineDragging {
            setCrossLineActive(false)
            setTouchCircle(nil)
        }
        crossDrag = nil
        crossLineDragging = false
    }

    /// Java `showCrossLineActive`: widen the cut line while dragging (6 -> 10 GL px).
    private func setCrossLineActive(_ active: Bool) {
        guard let renderer = renderers[2] else { return }
        var options = FoldRenderOptions()
        options.crossLineActive = active
        renderer.setOptions(options)
        if modeIndex == 2 { renderer.requestDraw() }
    }

    /// Java `showTouchCircleFm`: pink circle at the dragged object point.
    private func setTouchCircle(_ objectPoint: CGPoint?) {
        guard let renderer = renderers[2] else { return }
        var options = FoldRenderOptions()
        if let objectPoint, let pair = crossCameras {
            let radius = pair.bottom.getObjectRadiusFromTouchPxRadius()
            options.touchCircle = .set(FoldTouchCircle(panel: .bottom,
                                                       x: objectPoint.x,
                                                       y: objectPoint.y,
                                                       radius: radius))
        } else {
            options.touchCircle = .clear
        }
        renderer.setOptions(options)
        if modeIndex == 2 { renderer.requestDraw() }
    }

    /// Gesture handler bundle for `FoldGestureLayer`.
    var gestureHandlers: FoldGestureHandlers {
        FoldGestureHandlers(
            onTwoFingerStart: { [weak self] center in self?.twoFingerStart(at: center) },
            onTwoFingerMove: { [weak self] state in self?.twoFingerMove(state) },
            onTwoFingerEnd: { [weak self] in self?.twoFingerEnd() },
            onDragStart: { [weak self] point in self?.dragStart(at: point) },
            onDrag: { [weak self] point in self?.drag(to: point) },
            onDragEnd: { [weak self] in self?.dragEnd() },
            onCancel: { [weak self] in self?.gestureCancelled() })
    }

    // MARK: - Back

    /// `onBack()`: EditorActivity.returnToPaintFragment() (ui-canvas implements the reset).
    func back() {
        session.returnToPaint()
    }
}

// MARK: - Small math helpers (GeomUtil subset used by the cut-line gesture)

private enum FoldMath {
    /// `GeomUtil.constrain` (Java `Math.max(Math.min(d, max), min)`).
    static func constrain(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        max(min(value, maxValue), minValue)
    }

    /// `GeomUtil.clamp(i, n)`: non-negative modulo.
    static func wrapClamp(_ value: Int, _ modulus: Int) -> Int {
        guard modulus != 0 else { return 0 }
        let rest = value % modulus
        return rest < 0 ? rest + modulus : rest
    }
}
