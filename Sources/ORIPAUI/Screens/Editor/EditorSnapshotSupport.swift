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
import ImageIO
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
        // Picked lines render in COLOR_PICKED (green) above the typed CP lines.
        runtime.paintRenderer.setPickedLines([
            PaintLine(x0: -half * 0.5, y0: 0, x1: 0, y1: 0, typeCode: 2),
            PaintLine(x0: 0, y0: 0, x1: 0, y1: half * 0.5, typeCode: 3),
        ])
        runtime.paintRenderer.setPickedMVFBPoints([
            PaintPoint(x: -half * 0.5, y: 0),
            PaintPoint(x: 0, y: 0),
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

    // MARK: - Snapshot scenarios (appended by ui-shell's SnapshotScenarios.makeAll)

    /// Every editor-state scenario for `swift run ORIPASnapshots`.
    /// Portrait/landscape are the standard 820×1180 / 1180×820 canvases.
    @MainActor
    public static func scenarios() -> [SnapshotScenario] {
        var out: [SnapshotScenario] = []
        func host(_ app: AppModel, _ content: AnyView) -> AnyView {
            AnyView(SnapshotScreenHost(app: app, content: content).oripaSnapshotMode())
        }

        // 19 — paint screen, both toolbars, seeded pattern (grid + typed lines + vertices).
        var app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(SnapshotScenario(name: "19-editor-paint",
                                    size: SnapshotScenarios.portrait,
                                    title: "Editor — paint CP: main + top toolbar, grid/lines/vertices",
                                    view: host(app, paint(app: app))))

        // 20 — cascading Action menu open.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        let paintMenuView = paint(app: app)
        app.menus.show(anchor: CGRect(x: 330, y: 90, width: 120, height: 48),
                       items: PaintTools.actions.map { item in
                           OrMenuItem(label: item.title, icon: item.icon, kind: .radio,
                                      checked: item.id == PaintTools.Id.actionAddLine,
                                      action: {})
                       })
        out.append(SnapshotScenario(name: "20-editor-paint-action-menu",
                                    size: SnapshotScenarios.portrait,
                                    title: "Editor — Action cascading menu (Add/Change/Select/Delete/Clean Vertex)",
                                    view: host(app, paintMenuView)))

        // 21 — by-value column (Segment by Value).
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(SnapshotScenario(name: "21-editor-paint-by-value",
                                    size: SnapshotScenarios.portrait,
                                    title: "Editor — by-value column (angle / length / Get Angle)",
                                    view: host(app, paint(app: app, byValue: true))))

        // 22 — Select Line tool with a selection rectangle and picked lines.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(SnapshotScenario(name: "22-editor-paint-selection",
                                    size: SnapshotScenarios.portrait,
                                    title: "Editor — Select Line: dashed selection rectangle + picked lines",
                                    view: host(app, paintSelectionRect(app: app))))

        // 23 — menus hidden (Show Menus affordance only).
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(SnapshotScenario(name: "23-editor-paint-menus-hidden",
                                    size: SnapshotScenarios.portrait,
                                    title: "Editor — Hide Menus mode (Show Menus unfold icon)",
                                    view: host(app, paint(app: app, menusHidden: true))))

        // 24 — landscape paint layout.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(SnapshotScenario(name: "24-editor-paint-landscape",
                                    size: SnapshotScenarios.landscape,
                                    title: "Editor — paint CP landscape (iPad)",
                                    view: host(app, paint(app: app))))

        // 25 — AddSegment tool: a line drawn through the real state machine + history path.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        let drawn = drawLineScenario(app: app)
        out.append(SnapshotScenario(name: "25-editor-paint-add-segment",
                                    size: SnapshotScenarios.portrait,
                                    title: "Editor — AddSegment tap flow: \(drawn.linesBefore)→\(drawn.linesAfter) lines, undo enabled \(drawn.canUndo)",
                                    view: host(app, drawn.view)))

        // 26 — check screen: pink faces + typed lines (+ red error vertices for invalid CP).
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(SnapshotScenario(name: "26-editor-check",
                                    size: SnapshotScenarios.portrait,
                                    title: "Check — Local Flat Foldability (pink faces, red error vertices)",
                                    view: host(app, check(app: app))))

        // 27 — export CP dialog.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(app: app,
                                  name: "27-dialog-export-cp",
                                  title: "Export Crease Pattern (svg / png / opx / cp)") { app in
            let session = EditorSession(params: EditorParams(), app: app)
            ExportCPDialog.show(app.dialogs, fileExchange: app.fileExchange,
                                toast: app.toast, host: session)
        })

        // 28 — PNG options dialog (200…1600 step 40, default 1000).
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(app: app,
                                  name: "28-dialog-export-png",
                                  title: "PNG Options (image size, default 1000 px)") { app in
            let session = EditorSession(params: EditorParams(), app: app)
            ExportCPDialog.showPngOptions(app.dialogs, fileExchange: app.fileExchange,
                                          toast: app.toast, host: session)
        })

        // 29 — per-tool help dialog with the 160 dp illustration.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(app: app,
                                  name: "29-dialog-help-segment",
                                  title: "Paint help — Segment (160 dp illustration)") { app in
            HelpDialog.showForTool(app.dialogs, toolType: 0)
        })

        // 30 — save-changes dialog (SaveNew path).
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(app: app,
                                  name: "30-dialog-save-changes",
                                  title: "Save changes? (Save / Discard / Cancel)") { app in
            let session = EditorSession(params: EditorParams(), app: app)
            SaveDialog.showNew(app.dialogs, host: session)
        })

        // 31 — by-value angle dialog.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(app: app,
                                  name: "31-dialog-number-angle",
                                  title: "Set Angle (Degrees)") { app in
            NumberDialog.showAngle(app.dialogs, initialValue: 45) { _ in }
        })

        // 32 — read-only CP preview renderer (used by PreviewScreen / project previews).
        let previewCP = CreasePattern()
        seedDemoPattern(previewCP)
        if let preview = ORIPACanvasIntegration.previewView(opxcData: OripaIO.exportOpxc(previewCP)) {
            out.append(SnapshotScenario(
                name: "33-canvas-preview",
                size: SnapshotScenarios.portrait,
                title: "Canvas — read-only CP preview renderer (fit + typed lines)",
                view: AnyView(ZStack {
                    Color.white
                    preview
                }.oripaSnapshotMode())))
        }

        // 34 — full route integration: ORIPARootView → NavigationHost → editor factory →
        // EditorScreen → PaintScreen (validates ui-shell's registry wiring end to end).
        ORIPACanvasIntegration.install()
        let routedApp = DemoProjects.makeApp(projectNames: [],
                                             route: [.projects, .editor(EditorParams())])
        out.append(SnapshotScenario(
            name: "34-editor-route",
            size: SnapshotScenarios.portrait,
            title: "Editor route integration (ORIPARootView → editorScreenFactory)",
            view: AnyView(ORIPARootView(app: routedApp).oripaSnapshotMode())))

        return out
    }

    /// Runs the real paint tap flow twice (AddSegment, direct selection) and captures whether
    /// the state machine finished a history branch, so the snapshot proves the drawing path.
    public struct DrawnLineResult {
        public var view: AnyView
        public var linesBefore: Int
        public var linesAfter: Int
        public var canUndo: Bool
    }

    @MainActor
    public static func drawLineScenario(app: AppModel) -> DrawnLineResult {
        let runtime = makeRuntime(app: app)
        resetMenu(runtime.menu)
        seedDemoPattern(runtime.session.cp)
        let before = runtime.session.cp.lines.count
        runtime.paintCoordinator.configureRenderer()
        // The canvas viewport must be known before feeding touch coordinates (the real
        // Canvas sets it on first layout; headless there is no layout pass).
        runtime.paintRenderer.prepareForSize(SnapshotScenarios.portrait)
        // Two taps of the AddSegment tool on grid points that are not yet connected.
        let center = CGPoint(x: 410, y: 590)   // 820×1180 portrait canvas centre
        let scale = CGFloat(1180) / (2.0 * CGFloat(runtime.session.cp.creasePatternHalfSize))
        let a = CGPoint(x: center.x + (-100) * scale * 0.5, y: center.y + (-200) * scale * 0.5)
        let b = CGPoint(x: center.x + (200) * scale * 0.5, y: center.y + (100) * scale * 0.5)
        runtime.paintDriver.tap(x: a.x, y: a.y)
        runtime.paintDriver.tap(x: b.x, y: b.y)
        let after = runtime.session.cp.lines.count
        return DrawnLineResult(
            view: AnyView(PaintScreen(session: runtime.session,
                                      menu: runtime.menu,
                                      driver: runtime.paintDriver,
                                      renderer: runtime.paintRenderer,
                                      app: app,
                                      coordinator: runtime.paintCoordinator,
                                      interactionEnabled: false)),
            linesBefore: before,
            linesAfter: after,
            canUndo: runtime.paintDriver.canUndo)
    }

    // MARK: - Generic snapshot dialog card

    /// Shows a real Material dialog (u i-shell's `DialogCenter`/`OrDialogHost`, rendered
    /// eagerly in snapshot mode) over the paint screen.
    public static func dialogScenario(app: AppModel,
                                      name: String,
                                      title: String,
                                      prepare: (AppModel) -> Void) -> SnapshotScenario {
        prepare(app)
        return SnapshotScenario(
            name: name,
            size: SnapshotScenarios.portrait,
            title: title,
            view: AnyView(SnapshotScreenHost(app: app, content: paint(app: app)).oripaSnapshotMode()))
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
