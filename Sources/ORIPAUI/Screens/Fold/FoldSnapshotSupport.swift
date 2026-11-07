// Headless snapshot support for the fold screen (visual QA).
//
// `ORIPASnapshots` (ci-release) renders `SnapshotScenarios` (ui-shell) through SwiftUI
// `ImageRenderer`. This support type is the fold workstream's piece of that catalog: it
// builds fully configured, eagerly-entered fold screens (X-Ray / wireframe / Overlap /
// Overlap-shadow / Cut Line portrait + landscape, the three settings dialogs, the export
// dialogs and the HSV colour picker) over a **real folded model**.
//
// Model seeding: the same `Fixtures/cases/fu_character.cp` pattern as the reference
// screenshots `oripa-port/docs/screenshots/fold-fu-*.png`, folded through the real engine
// (`isFlatFoldable` -> `foldWithoutOverlap` -> `foldWithOverlap` -> `crossLineManager.getNew`);
// when the fixture is not next to the executable (e.g. a bare CI artifact run) it falls back
// to the synthetic waterbomb-base model of the web port's `ui-fold.html` harness.
//
// `ImageRenderer` never runs `.onAppear`/`.task`, so the view model is entered eagerly and
// `FoldScreenContent` is rendered directly (no platform gesture surface: ImageRenderer cannot
// rasterise `UIViewRepresentable`/`NSViewRepresentable`).
//
// QA-only: the shipping app never constructs these views (ui-canvas mounts
// `FoldScreen(session:app:)` on the real `EditorSession`).
import SwiftUI
import ORIPACore

/// Demo fold session + snapshot scenarios (no production code path uses this type).
@MainActor
public enum FoldSnapshot {

    // MARK: - Synthetic demo session (no fixtures needed)

    /// Build a real `EditorSession` (New File) whose folded model is the synthetic
    /// waterbomb-base pattern (square + both diagonals -> 4 stacked triangles).
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

    // MARK: - Real fixture-backed session

    /// Load a `.cp`/`.opx`/`.opxc` file and fold it (`isFlatFoldable` → `foldWithoutOverlap`
    /// → `foldWithOverlap` → `crossLineManager.getNew`, i.e. the `prepareFold` path).
    public static func loadSession(app: AppModel,
                                   fileURL: URL,
                                   name: String? = nil) -> (any EditorSessionProtocol)? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let filename = name ?? fileURL.lastPathComponent
        guard let cp = try? OripaIO.readCreasePatternFile(data: data, filename: filename) else {
            return nil
        }
        let fm = FoldedModel()
        let clm = CrossLineManager()
        let session = FoldDemoSession(cp: cp,
                                      foldedModel: fm,
                                      crossLineManager: clm,
                                      srcFilenameNoExt: (filename as NSString).deletingPathExtension,
                                      prefs: app.prefs)
        guard session.prepareFold() else { return nil }
        return session
    }

    /// Fixture used by the reference screenshots (`fold-fu-xray/overlap/cutline.png`).
    private static var fixtureURL: URL? {
        let candidates = [
            "Fixtures/cases/fu_character.cp",
            "../Fixtures/cases/fu_character.cp",
            "../../Fixtures/cases/fu_character.cp",
        ]
        let fileManager = FileManager.default
        for candidate in candidates where fileManager.fileExists(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return nil
    }

    private static func scenarioSession(app: AppModel) -> (any EditorSessionProtocol)? {
        if let url = fixtureURL, let session = loadSession(app: app, fileURL: url) {
            return session
        }
        return demoSession(app: app)
    }

    /// Reset the fold preference keys so scenarios do not leak state into each other when
    /// they share one `AppModel` (Android clears SharedPreferences on project entry too).
    private static func resetFoldPreferences(_ prefs: Preferences) {
        prefs.setBool(false, for: FoldPref.xrayStyleWire)
        prefs.setBool(true, for: FoldPref.crossOneFingerMove)
        prefs.setBool(FoldOverlapDefaults.flip, for: FoldPref.overlapFlip)
        prefs.setBool(true, for: FoldPref.overlapEnabled)
        prefs.setBool(false, for: FoldPref.overlapShadow)
        prefs.setInt(FoldOverlapDefaults.prefInt(fromColor: FoldOverlapDefaults.frontColor),
                     for: FoldPref.overlapFrontColor)
        prefs.setInt(FoldOverlapDefaults.prefInt(fromColor: FoldOverlapDefaults.backColor),
                     for: FoldPref.overlapBackColor)
        prefs.setInt(FoldOverlapDefaults.prefInt(fromColor: FoldOverlapDefaults.lineColor),
                     for: FoldPref.overlapLineColor)
    }

    // MARK: - Eagerly-entered screens

    /// A fold screen whose view model is already entered, for `ImageRenderer`.
    static func screen(app: AppModel,
                              modeIndex: Int,
                              size: CGSize = CGSize(width: 820, height: 1180),
                              sessionSetup: ((any EditorSessionProtocol) -> Void)? = nil,
                              modelSetup: ((FoldViewModel) -> Void)? = nil) -> AnyView? {
        resetFoldPreferences(app.prefs)
        guard let session = scenarioSession(app: app) else { return nil }
        sessionSetup?(session)
        let model = FoldViewModel(session: session, app: app, initialModeIndex: modeIndex)
        model.enter(size: size)
        modelSetup?(model)
        return AnyView(FoldScreenContent(model: model,
                                         safeArea: EdgeInsets(),
                                         rendersPlatformGestures: false)
            .frame(width: size.width, height: size.height))
    }

    // MARK: - Snapshot scenarios (appended by ui-shell to SnapshotScenarios.makeAll())

    /// Every fold snapshot scenario, seeded with a fresh snapshot app model.
    /// Names are prefixed `40-` so they sort after the shell scenarios in the artifact.
    public static func scenarios() -> [SnapshotScenario] {
        // Reuse ui-shell's temporary-directory snapshot AppModel factory (same module).
        scenarios(app: DemoProjects.makeApp(projectNames: []))
    }

    /// Every fold snapshot scenario for an existing snapshot app model.
    public static func scenarios(app: AppModel) -> [SnapshotScenario] {
        var list: [SnapshotScenario] = []
        let portrait = SnapshotScenarios.portrait
        let landscape = SnapshotScenarios.landscape

        func add(_ name: String,
                 _ title: String,
                 _ size: CGSize,
                 modeIndex: Int,
                 sessionSetup: ((any EditorSessionProtocol) -> Void)? = nil,
                 modelSetup: ((FoldViewModel) -> Void)? = nil) {
            guard let view = screen(app: app,
                                    modeIndex: modeIndex,
                                    size: size,
                                    sessionSetup: sessionSetup,
                                    modelSetup: modelSetup) else { return }
            list.append(SnapshotScenario(name: name, size: size, title: title, view: view))
        }

        add("40-fold-xray", "Fold — X-Ray / Wireframe", portrait, modeIndex: 0)
        add("41-fold-xray-wire", "Fold — X-Ray wireframe", portrait, modeIndex: 0,
            sessionSetup: { session in
                session.prefs.setBool(true, for: FoldPref.xrayStyleWire)
            })
        add("42-fold-overlap", "Fold — Overlap [BETA]", portrait, modeIndex: 1)
        add("43-fold-overlap-shadow", "Fold — Overlap + shadow", portrait, modeIndex: 1,
            sessionSetup: { session in
                session.prefs.setBool(true, for: FoldPref.overlapShadow)
            })
        add("44-fold-overlap-flip", "Fold — Overlap flipped", portrait, modeIndex: 1,
            sessionSetup: { session in
                session.prefs.setBool(true, for: FoldPref.overlapFlip)
            })
        add("45-fold-cross-portrait", "Fold — Cut Line (portrait)", portrait, modeIndex: 2)
        add("46-fold-cross-landscape", "Fold — Cut Line (landscape)", landscape, modeIndex: 2)
        add("47-fold-dlg-xray", "Fold — X-Ray settings", portrait, modeIndex: 0,
            modelSetup: { model in
                model.settingsSheet = .xray(initialWireframe: false)
            })
        add("48-fold-dlg-overlap", "Fold — Overlap settings", portrait, modeIndex: 1,
            modelSetup: { model in
                model.settingsSheet = .overlap(flip: false,
                                               front: FoldOverlapDefaults.frontColor,
                                               back: FoldOverlapDefaults.backColor,
                                               line: FoldOverlapDefaults.lineColor)
            })
        add("49-fold-dlg-cross", "Fold — Cut Line settings", portrait, modeIndex: 2,
            modelSetup: { model in
                model.openSettings()
            })
        add("50-fold-dlg-export", "Fold — Export Model dialog", portrait, modeIndex: 0,
            modelSetup: { model in
                model.openExport()
            })
        add("51-fold-dlg-png", "Fold — PNG Options dialog", portrait, modeIndex: 0,
            modelSetup: { model in
                model.exportSheet = .pngOptions(defaultSize: 1000)
            })
        if let base = screen(app: app, modeIndex: 1, size: portrait) {
            list.append(SnapshotScenario(name: "52-fold-dlg-color",
                                         size: portrait,
                                         title: "Fold — HSV colour picker",
                                         view: AnyView(ZStack {
                                             base
                                             FoldColorPickerDialog(
                                                 defaultColor: FoldOverlapDefaults.frontColor,
                                                 currentColor: FoldOverlapDefaults.frontColor,
                                                 onCancel: {},
                                                 onOK: { _ in })
                                         })))
        }
        add("53-fold-mode-menu", "Fold — mode spinner menu", portrait, modeIndex: 0,
            modelSetup: { model in
                model.showsModeMenu = true
            })
        return list
    }

    // MARK: - Dialog-only views (used by the local QA renderer)

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
    public static func rendererPNG(app: AppModel,
                                   mode: FoldMode,
                                   width: Int,
                                   height: Int) -> Data? {
        guard let session = scenarioSession(app: app) else { return nil }
        var options = FoldPNGExport.Options()
        options.cp = session.cp
        options.crossLineManager = session.crossLineManager
        options.crossAngleDeg = session.crossLineManager.getCurrentCrossLineAngleDeg()
        options.crossPosition = session.crossLineManager.getCurrentCrossLinePosition()
        return FoldPNGExport.render(fm: session.foldedModel,
                                    mode: mode,
                                    width: width,
                                    height: height,
                                    options: options)
    }
}

// MARK: - QA session

/// Minimal `EditorSessionProtocol` implementation for snapshot/QA rendering of a real
/// crease-pattern file. QA-only; the app uses ui-canvas' `EditorSession`.
@MainActor
public final class FoldDemoSession: EditorSessionProtocol {
    public let cp: CreasePattern
    public let foldedModel: FoldedModel
    public let crossLineManager: CrossLineManager
    public let prefs: Preferences
    public var srcFilenameNoExt: String
    public var srcIsInternal: Bool
    public var modified: Bool

    public init(cp: CreasePattern,
                foldedModel: FoldedModel,
                crossLineManager: CrossLineManager,
                srcFilenameNoExt: String,
                prefs: Preferences? = nil) {
        self.cp = cp
        self.foldedModel = foldedModel
        self.crossLineManager = crossLineManager
        self.srcFilenameNoExt = srcFilenameNoExt
        self.srcIsInternal = true
        self.modified = false
        self.prefs = prefs ?? Preferences()
    }

    public func returnToPaint() {}
    public func requestCloseProject() {}

    @discardableResult
    public func runFlatFoldabilityCheck() -> Bool {
        _ = cp.isFlatFoldable()
        return true
    }

    /// `PaintCpFragment.newFoldCP` path: isFlatFoldable → foldWithoutOverlap → optional
    /// foldWithOverlap → crossLineManager.getNew.
    @discardableResult
    public func prepareFold() -> Bool {
        guard cp.isFlatFoldable() else { return false }
        foldedModel.foldWithoutOverlap(cp)
        foldedModel.foldWithOverlap()
        crossLineManager.getNew(foldedModel)
        return true
    }
}
