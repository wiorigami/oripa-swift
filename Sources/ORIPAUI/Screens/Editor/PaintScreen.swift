// The paint crease-pattern screen.
//
// Port of `oripa-port/src/js/ui/fragments/paint.js` + `fragment_paint_cp.xml` +
// `GLSurfaceViewPaintCp`: full-screen white canvas with the two floating toolbars, the
// by-value column, the hide/show-menus mode and the FAB mini menu (Export / Fold / Check).
//
// Touch handling (port of GLSurfaceViewPaintCp):
//   tap        : snap = !(batch tool || !showGrid); radius = max(5e-4, object radius);
//                smm.doTransition; 0 → picked points, 1 → picked lines, 3 → finish+history
//   long press : smm.doLongTransition; mirror tool draws its temp line
//   drag       : dashed selection rectangle → doBatchPointOperation/doBatchLineOperation
//   two-finger : pan (translateTransformM) + pinch (scaleTransformM, clamped to
//                Constant.MIN/MAX_SCALE_FACTOR), no rotation for CP views (Android)
//   touch circle: 16 dp object radius, hidden after TOUCH_CIRCLE_DURATION_MILLISECONDS
import Foundation
import SwiftUI
import ORIPACore

/// Gesture + session glue for the paint canvas (kept out of the `View` so the recogniser
/// callbacks can mutate plain reference state).
@MainActor
final class PaintCoordinator {
    let session: EditorSession
    let menu: PaintMenuModel
    let driver: PaintDriver
    let renderer: PaintRenderer
    let app: AppModel
    let recognizer = CanvasGestureRecognizer()

    private var selectionInProgress = false
    private var selectionInterrupted = false
    private var suppressDrag = false
    private var initialSelectObjectXY: CGPoint?
    private var scaleFactor: CGFloat = 0.5
    private var lastTwo: (scale: CGFloat, cx: CGFloat, cy: CGFloat)?
    private var touchCircleWork: DispatchWorkItem?

    init(session: EditorSession, menu: PaintMenuModel, driver: PaintDriver,
         renderer: PaintRenderer, app: AppModel) {
        self.session = session
        self.menu = menu
        self.driver = driver
        self.renderer = renderer
        self.app = app
        bindCallbacks()
    }

    // MARK: - Configuration

    /// First entry: `initView()` + `initializeTools()`.
    func configureRenderer() {
        CoreRenderBridge.configurePaint(renderer, cp: session.cp, settings: session.settings)
        scaleFactor = CGFloat(renderer.viewTransform.getScaleFactor())
        renderer.setCurrentScaleFactor(scaleFactor)
        applyLineWidthScale()
        driver.initialize()
    }

    /// `resume()` after returning from Settings.
    func applySettings() {
        session.reloadSettings()
        let settings = session.settings
        renderer.setGridData(CoreRenderBridge.updateGrid(session.cp,
                                                         divisions: settings.gridDivisions,
                                                         gridType: settings.gridType))
        renderer.setPreferences(settings.paintPreferences)
        renderer.setInputLineType(menu.inputLineType)
        if driver.currentToolType == 0 || true {
            // PaintCpFragment.onActivityResult: recreate the machine when direct selection
            // changed (harmless otherwise — the picked state is cleared on resume).
        }
        driver.initialize()
    }

    private func applyLineWidthScale() {
        renderer.setLineWidthScaleFactor(renderer.viewTransform.getObjectValFromTouchPx(1.0))
    }

    private func onScaleFactorChange() {
        renderer.setCurrentScaleFactor(renderer.viewTransform.getScaleFactor())
        applyLineWidthScale()
        renderer.requestDraw()
    }

    // MARK: - Gesture callbacks

    private func bindCallbacks() {
        var callbacks = CanvasGestureRecognizer.Callbacks()
        callbacks.onDown = { [weak self] _, _ in
            self?.suppressDrag = false
        }
        callbacks.onSingleTapUp = { [weak self] x, y in
            self?.showTouchCircle(at: x, y: y)
        }
        callbacks.onTap = { [weak self] x, y in
            self?.driver.tap(x: x, y: y)
        }
        callbacks.onLongPress = { [weak self] x, y in
            self?.driver.longPress(x: x, y: y)
        }
        callbacks.onDragStart = { [weak self] x, y in
            self?.onDragStart(x: x, y: y)
        }
        callbacks.onDrag = { [weak self] x, y, _, _ in
            self?.dragMoved(x: x, y: y)
        }
        callbacks.onDragEnd = { [weak self] x, y in
            self?.onDragEnd(x: x, y: y)
        }
        callbacks.onTwoFingerStart = { [weak self] state in
            self?.onTwoFingerStart(state)
        }
        callbacks.onTwoFingerMove = { [weak self] state in
            self?.onTwoFingerMove(state)
        }
        callbacks.onTwoFingerEnd = { [weak self] in
            self?.lastTwo = nil
            self?.suppressDrag = true
            self?.selectionInProgress = false
        }
        recognizer.callbacks = callbacks
    }

    /// The recogniser only reports `onDrag` as (x, y, dx, dy); drive the rectangle through a
    /// small extension so both callbacks share the same conversion.
    func dragMoved(x: CGFloat, y: CGFloat) {
        guard selectionInProgress, !selectionInterrupted, let start = initialSelectObjectXY else { return }
        let end = objectPoint(x: x, y: y)
        renderer.setSelectionRect(x0: start.x, y0: start.y, x1: end.x, y1: end.y)
        renderer.requestDraw()
    }

    private func objectPoint(x: CGFloat, y: CGFloat) -> CGPoint {
        renderer.viewTransform.screenToObject(x: x, y: y)
    }

    private func onDragStart(x: CGFloat, y: CGFloat) {
        guard !suppressDrag, driver.isBatchOperation() else { return }
        selectionInProgress = true
        selectionInterrupted = false
        let start = objectPoint(x: x, y: y)
        initialSelectObjectXY = start
        renderer.setSelectionRect(x0: start.x, y0: start.y, x1: start.x, y1: start.y)
        renderer.requestDraw()
    }

    private func onDragEnd(x: CGFloat, y: CGFloat) {
        if suppressDrag {
            suppressDrag = false
            return
        }
        guard selectionInProgress else { return }
        let wasInterrupted = selectionInterrupted
        let initial = initialSelectObjectXY
        selectionInProgress = false
        selectionInterrupted = false
        initialSelectObjectXY = nil
        renderer.clearSelection()
        renderer.requestDraw()
        guard !wasInterrupted, let start = initial else { return }
        driver.batchOperation(start: start, end: objectPoint(x: x, y: y))
    }

    private func onTwoFingerStart(_ state: TwoFingerState) {
        lastTwo = (scale: 1, cx: state.cx, cy: state.cy)
        suppressDrag = true
        selectionInProgress = false
        selectionInterrupted = false
        initialSelectObjectXY = nil
        renderer.clearSelection()
    }

    private func onTwoFingerMove(_ state: TwoFingerState) {
        let previous = lastTwo ?? (scale: 1, cx: state.cx, cy: state.cy)
        let factor = previous.scale > 0 ? state.scale / previous.scale : 1
        let panDx = state.cx - previous.cx
        let panDy = state.cy - previous.cy
        lastTwo = (scale: state.scale, cx: state.cx, cy: state.cy)

        let vt = renderer.viewTransform
        if panDx != 0 || panDy != 0 {
            vt.translateTransformM(dxPx: panDx, dyPx: panDy)
        }
        if factor != 1 {
            let candidate = scaleFactor * factor
            if candidate <= Camera.MAX_SCALE_FACTOR && candidate >= Camera.MIN_SCALE_FACTOR {
                scaleFactor = candidate
                vt.setScaleFactor(candidate)
                vt.scaleTransformM(factor: factor, focusXPx: state.cx, focusYPx: state.cy)
                onScaleFactorChange()
            }
        }
        renderer.requestDraw()
    }

    // MARK: - Touch circle

    private func showTouchCircle(at x: CGFloat, y: CGFloat) {
        let obj = objectPoint(x: x, y: y)
        let radius = max(5.0e-4, renderer.viewTransform.getObjectRadiusFromTouchPxRadius())
        renderer.showTouchCircle(x: obj.x, y: obj.y, radius: radius)
        renderer.requestDraw()
        touchCircleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.renderer.hideTouchCircle()
            self?.renderer.requestDraw()
        }
        touchCircleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    /// Screen point in object coordinates (used by the drag rectangle callback wiring).
    func screenToObject(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        objectPoint(x: x, y: y)
    }
}

// MARK: - Screen

public struct PaintScreen: View {
    @ObservedObject var session: EditorSession
    @ObservedObject var menu: PaintMenuModel
    @ObservedObject var driver: PaintDriver
    @ObservedObject var renderer: PaintRenderer
    let app: AppModel
    let coordinator: PaintCoordinator

    @State private var loadingText: String?
    @State private var didAppear = false
    /// Snapshot/QA rendering has no window: `ImageRenderer` cannot rasterise the platform
    /// input surface (NSView/UIView), so snapshots build the screen without it.
    private let interactionEnabled: Bool

    init(session: EditorSession, menu: PaintMenuModel, driver: PaintDriver,
         renderer: PaintRenderer, app: AppModel, coordinator: PaintCoordinator,
         interactionEnabled: Bool = true) {
        self.session = session
        self.menu = menu
        self.driver = driver
        self.renderer = renderer
        self.app = app
        self.coordinator = coordinator
        self.interactionEnabled = interactionEnabled
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.white
                PaintCanvasView(renderer: renderer)
                    .contentShape(Rectangle())
                // Transparent input surface above the drawing canvas (the recogniser turns
                // raw touches into tap / long-press / drag / pinch / two-finger pan).
                if interactionEnabled {
                    CanvasGestureOverlay(recognizer: coordinator.recognizer)
                        .ignoresSafeArea()
                }

                overlayChrome(size: proxy.size)
            }
            .background(Color.white)
            .onAppear {
                guard !didAppear else {
                    coordinator.applySettings()
                    return
                }
                didAppear = true
                coordinator.configureRenderer()
            }
        }
    }

    // MARK: - Chrome

    @ViewBuilder
    private func overlayChrome(size: CGSize) -> some View {
        ZStack(alignment: .top) {
            if !menu.menusHidden {
                VStack(spacing: 10) {
                    PaintMainToolbar(canUndo: driver.canUndo,
                                     canRedo: driver.canRedo,
                                     onDone: { session.closeProject() },
                                     onToggleDrawTools: { menu.toggleDrawTools() },
                                     onUndo: { driver.undo() },
                                     onRedo: { driver.redo() },
                                     onSettings: { app.push(.settings) },
                                     onHideMenus: { menu.setMenusHidden(true) })
                    if menu.topToolbarShown {
                        PaintTopToolbar(menu: menu,
                                        onAction: { applyAction($0) },
                                        onMethod: { applyMethod($0) },
                                        onLineType: { applyLineType($0) },
                                        onChangeFrom: { menu.applyChangeFrom($0) },
                                        onChangeTo: { menu.applyChangeTo($0) },
                                        onDeleteType: { menu.applyDeleteType($0) },
                                        onHelp: { HelpDialog.showForTool(app.dialogs, toolType: driver.currentToolType) },
                                        onClearSelection: { driver.clearSelectionAction() },
                                        onSelectAll: { driver.selectAllLines() },
                                        onDeselectAll: { driver.deselectAllLines() },
                                        onDeleteSelected: { driver.deleteSelectedLines() })
                    }
                }
                .padding(.top, 0)
            }

            if menu.menusHidden {
                HStack {
                    Spacer()
                    ShowMenusButton { menu.setMenusHidden(false) }
                }
                .padding(.trailing, 4)
                .padding(.top, 4)
            }

            if menu.byValueVisible {
                HStack {
                    PaintByValueColumn(menu: menu,
                                       onAngleTap: showAngleDialog,
                                       onLengthTap: showLengthDialog,
                                       onByValueEntrySelected: { index in
                                           menu.setByValueIndex(index)
                                           driver.applyByValueEntry()
                                       })
                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.top, 132)
            }

            if let loadingText {
                OrProgressOverlay(loadingText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            if !menu.menusHidden {
                PaintFab(onExport: showExportDialog,
                         onFold: runFold,
                         onCheck: runCheck)
            }
        }
    }

    // MARK: - Menu actions

    private func applyAction(_ id: Int) {
        menu.applyAction(id)
        driver.rebuildMachineForCurrentAction()
        driver.clearPicked()
        renderer.requestDraw()
    }

    private func applyMethod(_ id: Int) {
        menu.applyMethod(id)
        if menu.currentAction.action == .add {
            driver.rebuildMachineForCurrentAction()
        }
        driver.clearPicked()
        renderer.requestDraw()
    }

    private func applyLineType(_ id: Int) {
        menu.applyLineType(id)
        driver.applyLineType()
        renderer.requestDraw()
    }

    // MARK: - By-value dialogs

    private func showAngleDialog() {
        NumberDialog.showAngle(app.dialogs, initialValue: menu.byValueAngleValue) { value in
            menu.setByValueAngle(value)
        }
    }

    private func showLengthDialog() {
        NumberDialog.showLength(app.dialogs, initialValue: menu.byValueLengthValue) { value in
            menu.setByValueLength(value)
        }
    }

    // MARK: - FAB actions

    private func showExportDialog() {
        ExportCPDialog.show(app.dialogs, fileExchange: app.fileExchange,
                           toast: app.toast, host: session)
    }

    /// PaintCpFragment.newCheckCP: isFlatFoldable() then show the check fragment.
    private func runCheck() {
        withProgress {
            _ = session.runFlatFoldabilityCheck()
        }
    }

    /// PaintCpFragment.newFoldCP: isFlatFoldable + fold + cross-line data, then fold fragment.
    private func runFold() {
        withProgress {
            if session.prepareFold() {
                session.setFragment(.fold)
            } else {
                app.dialogs.showError(session.lastFoldError ?? PaintStrings.foldError)
            }
        }
    }

    /// Large patterns block the UI while folding; show the Material progress overlay first
    /// (Android shows no progress, but an ANR is not acceptable on iPad).
    private func withProgress(_ task: @escaping () -> Void) {
        loadingText = PaintStrings.loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            task()
            loadingText = nil
        }
    }
}
