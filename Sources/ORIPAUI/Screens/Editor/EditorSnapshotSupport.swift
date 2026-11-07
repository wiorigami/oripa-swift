// Headless snapshot scenarios for the editor (paint / check / CP export dialog).
//
// The official snapshot list is assembled by ui-shell (`SnapshotScenarios.makeAll()`);
// this support type gives it pre-configured, renderable editor screens plus the
// dialog-overlay variants, so `swift run ORIPASnapshots` can render the editor states in
// `oripa-port/tools/ui_harness/screenshots/ui-editor-*.png`.
//
// `ImageRenderer` never runs `.onAppear`/`.task`, so every renderer is configured eagerly
// here (and the session seeded) before the view is returned.
import Foundation
import SwiftUI
import ORIPACore

@MainActor
public enum EditorSnapshotSupport {
    // MARK: - Scenarios

    /// Paint screen with both toolbars shown and the demo pattern (matches
    /// `ui-editor-paint-tools.png`).
    public static func paint(app: AppModel,
                             showTopToolbar: Bool = true,
                             menusHidden: Bool = false,
                             byValue: Bool = false) -> AnyView {
        let runtime = makeRuntime(app: app)
        resetMenu(runtime.menu)
        seedDemoPattern(runtime.session.cp)
        runtime.paintCoordinator.configureRenderer()
        runtime.menu.topToolbarShown = showTopToolbar
        runtime.menu.menusHidden = menusHidden
        if byValue {
            runtime.menu.applyMethod(PaintTools.Id.methodByValue)
            runtime.menu.topToolbarShown = true
            runtime.paintDriver.rebuildMachineForCurrentAction()
        }
        return AnyView(PaintScreen(session: runtime.session,
                                  menu: runtime.menu,
                                  driver: runtime.paintDriver,
                                  renderer: runtime.paintRenderer,
                                  app: app,
                                  coordinator: runtime.paintCoordinator,
                                  interactionEnabled: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity))
    }

    /// Paint screen with a dialog overlay (Export CP / PNG options / help / save / number).
    public static func paintDialog(app: AppModel, dialog: Dialog) -> AnyView {
        let runtime = makeRuntime(app: app)
        seedDemoPattern(runtime.session.cp)
        runtime.paintCoordinator.configureRenderer()
        runtime.menu.topToolbarShown = true
        present(dialog, app: app, session: runtime.session)
        return AnyView(ZStack {
            PaintScreen(session: runtime.session,
                        menu: runtime.menu,
                        driver: runtime.paintDriver,
                        renderer: runtime.paintRenderer,
                        app: app,
                        coordinator: runtime.paintCoordinator,
                        interactionEnabled: false)
            OrDialogHost(center: app.dialogs)
        })
    }

    /// Check screen with the flat-foldability data filled in.
    public static func check(app: AppModel, foldable: Bool = true) -> AnyView {
        let runtime = makeRuntime(app: app)
        seedCheckPattern(runtime.session.cp)
        _ = runtime.session.cp.isFlatFoldable()
        return AnyView(CheckScreen(session: runtime.session,
                                   renderer: runtime.checkRenderer,
                                   app: app,
                                   coordinator: runtime.checkCoordinator,
                                   interactionEnabled: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity))
    }

    /// Paint screen with a dragged selection rectangle over the Select Line tool.
    public static func paintSelectionRect(app: AppModel) -> AnyView {
        let runtime = makeRuntime(app: app)
        seedDemoPattern(runtime.session.cp)
        runtime.paintCoordinator.configureRenderer()
        runtime.menu.topToolbarShown = true
        runtime.menu.applyAction(PaintTools.Id.actionSelectLine)
        runtime.paintDriver.rebuildMachineForCurrentAction()
        let half = CGFloat(runtime.session.cp.creasePatternHalfSize)
        runtime.paintRenderer.setSelectionRect(x0: -half, y0: -half, x1: half * 0.6, y1: half * 0.4)
        runtime.paintRenderer.setPickedLines([
            PaintLine(x0: -half, y0: -half, x1: half, y1: -half, typeCode: 1),
            PaintLine(x0: -half, y0: -half, x1: half, y1: half, typeCode: 2),
        ])
        runtime.paintRenderer.requestDraw()
        return AnyView(PaintScreen(session: runtime.session,
                                  menu: runtime.menu,
                                  driver: runtime.paintDriver,
                                  renderer: runtime.paintRenderer,
                                  app: app,
                                  coordinator: runtime.paintCoordinator,
                                  interactionEnabled: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity))
    }

    // MARK: - Dialogs

    public enum Dialog {
        case exportCP
        case exportPNG
        case help(toolType: Int)
        case saveNew
        case saveExisting
        case numberAngle
    }

    private static func present(_ dialog: Dialog, app: AppModel, session: EditorSession) {
        switch dialog {
        case .exportCP:
            ExportCPDialog.show(app.dialogs, fileExchange: app.fileExchange,
                                toast: app.toast, host: session)
        case .exportPNG:
            ExportCPDialog.showPngOptions(app.dialogs, fileExchange: app.fileExchange,
                                          toast: app.toast, host: session)
        case .help(let toolType):
            HelpDialog.showForTool(app.dialogs, toolType: toolType)
        case .saveNew:
            SaveDialog.showNew(app.dialogs, host: session)
        case .saveExisting:
            SaveDialog.showExisting(app.dialogs, host: session)
        case .numberAngle:
            NumberDialog.showAngle(app.dialogs, initialValue: 45) { _ in }
        }
    }

    // MARK: - Runtime construction

    /// Standalone runtime used by snapshots: a fresh session for a New File project with a
    /// throw-away store so nothing is written to the user's Documents.
    static func makeRuntime(app: AppModel) -> EditorRuntime {
        EditorRuntime(params: EditorParams(), app: app)
    }

    /// Deterministic menu state for snapshots (a fresh install's defaults).
    static func resetMenu(_ menu: PaintMenuModel) {
        menu.applyAction(PaintTools.PrefDefault.drawAction)
        menu.applyMethod(PaintTools.PrefDefault.addMethod)
        menu.applyLineType(PaintTools.PrefDefault.addLineType)
        menu.applyChangeFrom(PaintTools.PrefDefault.changeLineTypeFrom)
        menu.applyChangeTo(PaintTools.PrefDefault.changeLineTypeTo)
        menu.applyDeleteType(PaintTools.PrefDefault.deleteLineType)
    }

    // MARK: - Demo patterns

    /// Simple crease pattern with mountain/valley/boundary lines (the paint screenshots'
    /// 4×4 grid square pattern).
    public static func seedDemoPattern(_ cp: CreasePattern) {
        cp.clearAll()
        cp.initializeDefaultSquare()
        let h = Double(cp.creasePatternHalfSize)
        let half = h
        func add(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ type: LineType) {
            cp.addLineCheckNoException(OriLine(OriPoint(x0, y0), OriPoint(x1, y1), type))
        }
        // centre cross (valley/mountain split like the harness demo pattern)
        add(-half, 0, 0, 0, .mountain)
        add(0, 0, half, 0, .valley)
        add(0, -half, 0, 0, .mountain)
        add(0, 0, 0, half, .valley)
        // inner square
        let q = half / 2
        add(-q, -q, q, -q, .mountain)
        add(q, -q, q, q, .mountain)
        add(q, q, -q, q, .valley)
        add(-q, q, -q, -q, .valley)
        // diagonals
        add(-half, -half, 0, 0, .mountain)
        add(0, 0, half, half, .valley)
        add(half, -half, 0, 0, .valley)
        add(0, 0, -half, half, .mountain)
        cp.modified = false
    }

    /// Locally flat-foldable pattern for the check screen (the harness check screenshot:
    /// square + centre cross + inner square + diagonals, all Kawasaki-valid).
    public static func seedCheckPattern(_ cp: CreasePattern) {
        seedDemoPattern(cp)
        cp.modified = false
    }
}
