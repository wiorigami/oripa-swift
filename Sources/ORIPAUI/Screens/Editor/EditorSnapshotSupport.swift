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

    // MARK: - Snapshot scenarios (appended by ui-shell's SnapshotScenarios.makeAll)

    /// Every editor-state scenario for `swift run ORIPASnapshots`.
    /// Portrait/landscape are the standard 820×1180 / 1180×820 canvases.
    @MainActor
    public static func scenarios() -> [SnapshotScenario] {
        var out: [SnapshotScenario] = []
        func host(_ app: AppModel, _ content: AnyView) -> AnyView {
            AnyView(SnapshotScreenHost(app: app, content: content))
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
        out.append(dialogScenario(
            app: app,
            name: "27-dialog-export-cp",
            title: "Export Crease Pattern (svg / png / opx / cp)",
            dialogTitle: PaintStrings.exportTitle,
            icon: "ic_file_download_dark_24dp",
            content: ExportCPDialog.snapshotContent(),
            buttons: [("Cancel", false), ("Export", true)]))

        // 28 — PNG options dialog (200…1600 step 40, default 1000).
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(
            app: app,
            name: "28-dialog-export-png",
            title: "PNG Options (image size, default 1000 px)",
            dialogTitle: PaintStrings.pngOptionsTitle,
            icon: "ic_image_dark_24dp",
            content: ExportCPDialog.snapshotPNGOptionsContent(),
            buttons: [("Cancel", false), ("OK", true)]))

        // 29 — per-tool help dialog with the 160 dp illustration.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(
            app: app,
            name: "29-dialog-help-segment",
            title: "Paint help — Segment (160 dp illustration)",
            dialogTitle: HelpDialog.entry(forTool: 0).title,
            icon: "ic_help_outline_dark_24dp",
            content: HelpDialog.snapshotContent(toolType: 0),
            buttons: [("Close", true)],
            width: 320))

        // 30 — save-changes dialog (SaveNew path).
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(
            app: app,
            name: "30-dialog-save-changes",
            title: "Save changes? (Save / Discard / Cancel)",
            dialogTitle: PaintStrings.saveChangesTitle,
            icon: "ic_save_dark_24dp",
            content: AnyView(EmptyView()),
            buttons: [("Cancel", false), ("Discard", false), ("Save", true)]))

        // 31 — by-value angle dialog.
        app = DemoProjects.makeApp(projectNames: [], route: [.projects])
        out.append(dialogScenario(
            app: app,
            name: "31-dialog-number-angle",
            title: "Set Angle (Degrees)",
            dialogTitle: PaintStrings.angleDialogTitle,
            icon: "ic_angle_dark_v2_24px",
            content: NumberDialog.snapshotContent(hint: PaintStrings.angleDialogHint, value: "45"),
            buttons: [("Cancel", false), ("OK", true)],
            width: 320))

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
        // Two taps of the AddSegment tool at (-100,-100) and (100,100) in object space.
        let center = CGPoint(x: 410, y: 590)   // 820×1180 portrait canvas centre
        let scale = CGFloat(1180) / (2.0 * CGFloat(runtime.session.cp.creasePatternHalfSize))
        let a = CGPoint(x: center.x + (-100) * scale * 0.5, y: center.y + (-100) * scale * 0.5)
        let b = CGPoint(x: center.x + (100) * scale * 0.5, y: center.y + (100) * scale * 0.5)
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

    /// Material dialog card for snapshots (the real `OrDialogHost` uses a `ScrollView`,
    /// which ImageRenderer renders empty headlessly).
    public static func dialogScenario(app: AppModel,
                                      name: String,
                                      title: String,
                                      dialogTitle: String,
                                      icon: String?,
                                      content: AnyView,
                                      buttons: [(String, Bool)],
                                      width: CGFloat = 320) -> SnapshotScenario {
        let background = ZStack {
            paint(app: app)
            OrTheme.scrim
            SnapshotDialogCard(title: dialogTitle, icon: icon, content: content,
                               buttons: buttons, width: width)
        }
        return SnapshotScenario(
            name: name,
            size: SnapshotScenarios.portrait,
            title: title,
            view: AnyView(SnapshotScreenHost(app: app, content: background)))
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

// MARK: - Snapshot dialog card

/// Material dialog chrome without a `ScrollView` (see `dialogScenario`).
private struct SnapshotDialogCard: View {
    let title: String
    let icon: String?
    let content: AnyView
    let buttons: [(String, Bool)]
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                if let icon {
                    MaterialIcon(icon, size: 24, tint: OrTheme.iconActive)
                }
                Text(title)
                    .font(OrTheme.dialogTitle())
                    .foregroundColor(OrTheme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            content
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                    OrTextButton(button.0, isPrimary: button.1) {}
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: OrTheme.dialogActionsHeight)
        }
        .frame(width: width, alignment: .leading)
        .background(OrTheme.dialogBackground)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .orElevation(24)
    }
}
