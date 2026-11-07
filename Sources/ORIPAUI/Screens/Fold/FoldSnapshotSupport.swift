// Headless snapshot support for the fold screen (visual QA).
//
// `ORIPASnapshots` renders `SnapshotScenarios` (ui-shell) through SwiftUI `ImageRenderer`.
// This helper gives that catalog a real fold session seeded with the same synthetic
// waterbomb-base folded model the web port's `tools/ui_harness/ui-fold.html` uses
// (square + both diagonals -> 4 stacked triangles), plus standalone dialog views, so the
// X-Ray / Overlap / Cut Line screens and the settings/export/colour dialogs can be
// compared with `oripa-port/docs/screenshots/fold-*.png` and `ref/screen2.png`/`screen3.png`.
//
// It is QA-only: the shipping app never constructs these views (ui-canvas mounts
// `FoldScreen(session:app:)` on the real `EditorSession`).
import SwiftUI
import ORIPACore

/// Demo fold session + snapshot views (no production code path uses this type).
@MainActor
public enum FoldSnapshot {

    // MARK: - Demo session

    /// Build a real `EditorSession` (New File) whose folded model is the synthetic
    /// waterbomb-base pattern, ready for `FoldScreen(session:app:)`.
    public static func demoSession(app: AppModel) -> (any EditorSessionProtocol)? {
        let session = EditorSession(params: .newFile, app: app)
        let cp = session.cp
        let fm = session.foldedModel
        let clm = session.crossLineManager

        let facesCheck = demoFacesCheck()
        cp.clearAll()
        cp.creasePatternHalfSize = 200
        cp.modified = false
        cp.facesCheck = facesCheck
        cp.minMaxCheck = MinMaxDouble(-200, -200, 200, 200)
        fm.foldWithoutOverlap(facesCheck: facesCheck)
        fm.foldWithOverlap()
        clm.getNew(fm)
        return session
    }

    /// `facesCheck` of the harness waterbomb base: four triangles around the centre with
    /// alternating mountain/valley creases (real flat-foldable assignment).
    private static func demoFacesCheck() -> [OriPolygon] {
        func point(_ x: Double, _ y: Double) -> OriPoint { OriPoint(x, y) }
        let a = point(-200, -200)
        let b = point(200, -200)
        let c = point(200, 200)
        let d = point(-200, 200)
        let o = point(0, 0)
        let boundary = LineType.boundary.rawValue
        let mountain = LineType.mountain.rawValue
        let valley = LineType.valley.rawValue
        return [
            OriPolygon([a, b, o], [boundary, mountain, valley]),
            OriPolygon([b, c, o], [boundary, valley, mountain]),
            OriPolygon([c, d, o], [boundary, mountain, valley]),
            OriPolygon([d, a, o], [boundary, valley, mountain]),
        ]
    }

    // MARK: - Screen scenarios

    /// The fold screen in one of the three modes (spinner index).
    public static func screen(app: AppModel, modeIndex: Int) -> AnyView? {
        guard let session = demoSession(app: app) else { return nil }
        return AnyView(FoldScreen(session: session,
                                  app: app,
                                  initialModeIndex: modeIndex,
                                  rendersPlatformGestures: false))
    }

    // MARK: - Dialog scenarios

    /// X-Ray settings dialog (multi-choice "Use wireframe mode").
    public static func xraySettingsDialog() -> AnyView {
        AnyView(FoldXraySettingsDialog(initialWireframe: false,
                                       onWireframe: { _ in },
                                       onDismiss: {})
            .background(FoldTheme.surface))
    }

    /// Overlap settings dialog (flip + the three colour picker rows).
    public static func overlapSettingsDialog() -> AnyView {
        AnyView(FoldOverlapSettingsDialog(
            initialFlip: false,
            initialFrontColor: FoldOverlapDefaults.frontColor,
            initialBackColor: FoldOverlapDefaults.backColor,
            initialLineColor: FoldOverlapDefaults.lineColor,
            onFlip: { _ in },
            onColors: { _, _, _ in },
            onDismiss: {})
            .background(FoldTheme.surface))
    }

    /// Cut Line settings dialog (position/angle seekbars + checkboxes).
    public static func crossLineSettingsDialog() -> AnyView {
        AnyView(FoldCrossLineSettingsDialog(
            initialAngleDeg: 180,
            initialPosition: 300,
            initialButtonVisible: true,
            angleDegMax: 360,
            positionMax: 600,
            wireframeInitial: false,
            onUpdate: { _, _ in },
            onWireframe: { _ in },
            onButtonVisible: { _ in },
            onConfirm: { _, _, _ in },
            onCancel: {})
            .background(FoldTheme.surface))
    }

    /// Fold export "Export Model" file-type dialog.
    public static func exportDialog() -> AnyView {
        AnyView(FoldExportFileTypeDialog(fileTypes: [.svg, .png],
                                         onSelect: { _ in },
                                         onCancel: {})
            .background(FoldTheme.surface))
    }

    /// Fold export "PNG Options" dialog (Android NumberPicker wheel).
    public static func pngOptionsDialog() -> AnyView {
        AnyView(FoldPngOptionsDialog(defaultSize: 1000, onOK: { _ in }, onCancel: {})
            .background(FoldTheme.surface))
    }

    /// HSV colour picker dialog (used by the Overlap colour rows).
    public static func colorPickerDialog() -> AnyView {
        AnyView(FoldColorPickerDialog(defaultColor: FoldOverlapDefaults.frontColor,
                                      currentColor: FoldOverlapDefaults.frontColor,
                                      onCancel: {},
                                      onOK: { _ in })
            .background(FoldTheme.surface))
    }

    // MARK: - Renderer-only PNGs (pixel QA of the three views)

    /// PNG bytes of the fold renderer in `mode`, e.g. for pixel comparisons against
    /// `oripa-port/docs/screenshots/fold-*.png` (`FoldPNGExport` is the export path).
    public static func rendererPNG(mode: FoldMode, width: Int, height: Int) -> Data? {
        guard let session = demoSession(app: AppModel()) else { return nil }
        let fm = session.foldedModel
        var options = FoldPNGExport.Options()
        options.cp = session.cp
        options.crossLineManager = session.crossLineManager
        options.crossAngleDeg = session.crossLineManager.getCurrentCrossLineAngleDeg()
        options.crossPosition = session.crossLineManager.getCurrentCrossLinePosition()
        return FoldPNGExport.render(fm: fm, mode: mode, width: width, height: height, options: options)
    }
}
