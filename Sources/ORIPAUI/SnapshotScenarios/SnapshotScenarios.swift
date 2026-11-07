// Headless visual-QA scenarios for `swift run ORIPASnapshots`.
//
// Contract §5.2: `SnapshotScenarios.all` returns named, renderable scenarios seeded with
// demo projects; `ci-release`'s ORIPASnapshots executable renders them with ImageRenderer.
// Every scenario is a fully wired view (environment objects + overlays included), sized like
// the reference screenshots (820×1180 portrait / 1180×820 landscape).
//
// Seed data lives in a temporary directory, never in the real `~/Documents`, and uses the
// synthetic `DemoProjects` crease patterns (see DemoProjects.swift).
import SwiftUI
import ORIPACore

/// One renderable snapshot scenario.
public struct SnapshotScenario: Identifiable {
    /// Slug used for the PNG filename, e.g. "02-projects-grid".
    public let name: String
    /// Render size in points (portrait 820×1180 like the reference screenshots).
    public let size: CGSize
    /// Human-readable label.
    public let title: String
    /// The fully wired screen to render.
    public let view: AnyView

    public var id: String { name }

    public init(name: String, size: CGSize, title: String? = nil, view: AnyView) {
        self.name = name
        self.size = size
        self.title = title ?? name
        self.view = view
    }
}

/// Registry of every snapshot scenario.
@MainActor
public enum SnapshotScenarios {

    public static let portrait = CGSize(width: 820, height: 1180)
    public static let landscape = CGSize(width: 1180, height: 820)

    private static var cached: [SnapshotScenario]?

    /// Cached scenario list (rendering may mutate dialog/menu centers; use `makeAll()` when
    /// a fresh set of app models is needed).
    public static var all: [SnapshotScenario] {
        if let cached { return cached }
        let scenarios = makeAll()
        cached = scenarios
        return scenarios
    }

    /// Fresh scenarios with brand-new AppModel/ProjectStore instances.
    public static func makeAll() -> [SnapshotScenario] {
        installSnapshotPreviewRenderer()
        var scenarios: [SnapshotScenario] = []

        // MARK: Splash
        let splashApp = DemoProjects.makeApp(projectNames: [], route: [.splash])
        scenarios.append(SnapshotScenario(
            name: "01-splash",
            size: portrait,
            title: "Splash (grey_50 + wordmark, 800 ms)",
            view: rootView(splashApp, size: portrait)
        ))

        // MARK: Projects (grid / landscape / list / sort / empty / selection)
        // The six projects of the reference screenshots (fixed names + mtimes + line art).
        let gridNames = DemoProjects.referenceProjectNames
        let gridApp = DemoProjects.makeApp(projectNames: gridNames, route: [.projects])
        scenarios.append(SnapshotScenario(
            name: "02-projects-grid",
            size: portrait,
            title: "Projects — grid, sorted by last modified (6 Files)",
            view: rootView(gridApp, size: portrait)
        ))
        let landscapeApp = DemoProjects.makeApp(projectNames: gridNames, route: [.projects])
        scenarios.append(SnapshotScenario(
            name: "03-projects-grid-landscape",
            size: landscape,
            title: "Projects — landscape grid (7 columns)",
            view: rootView(landscapeApp, size: landscape)
        ))
        let emptyApp = DemoProjects.makeApp(projectNames: [], route: [.projects])
        scenarios.append(SnapshotScenario(
            name: "04-projects-empty",
            size: portrait,
            title: "Projects — empty (0 Files, blank content area, FAB)",
            view: rootView(emptyApp, size: portrait)
        ))

        let listNames = DemoProjects.referenceProjectNames
        let listApp = DemoProjects.makeApp(projectNames: listNames, route: [.projects])
        scenarios.append(SnapshotScenario(
            name: "05-projects-list",
            size: portrait,
            title: "Projects — list view (Modified: %s)",
            view: screenView(listApp, size: portrait) {
                ProjectsScreen(initialShowList: true)
            }
        ))
        let sortApp = DemoProjects.makeApp(projectNames: listNames, route: [.projects])
        scenarios.append(SnapshotScenario(
            name: "06-projects-sort-name",
            size: portrait,
            // Reference `06-projects-sort-name.png`: grid view, sorted by name.
            title: "Projects — grid sorted by name",
            view: screenView(sortApp, size: portrait) {
                ProjectsScreen(initialSortLastModified: false)
            }
        ))
        let selectionApp = DemoProjects.makeApp(projectNames: listNames, route: [.projects])
        scenarios.append(SnapshotScenario(
            name: "07-projects-selection",
            size: portrait,
            // Reference `projects-select.png`: grid view with the first project selected.
            title: "Projects — contextual action bar (1 selected, grid)",
            view: screenView(selectionApp, size: portrait) {
                ProjectsScreen(initialSelection: ["test-square"],
                               initialActionMode: true)
            }
        ))

        // MARK: Project dialogs
        // Reference `08-projects-delete-multiple.png`: selection mode with one file
        // selected and the "Delete 1 file?" confirmation above the action bar.
        let deleteMultipleApp = DemoProjects.makeApp(projectNames: listNames, route: [.projects])
        ProjectDialogs.deleteMultiple(app: deleteMultipleApp, count: 1) {}
        scenarios.append(SnapshotScenario(
            name: "08-dialog-delete-multiple",
            size: portrait,
            title: "Delete 1 file? / Cancel / Delete All (1 selected)",
            view: screenView(deleteMultipleApp, size: portrait) {
                ProjectsScreen(initialSelection: ["test-square"], initialActionMode: true)
            }
        ))

        let menuApp = DemoProjects.makeApp(projectNames: gridNames, route: [.projects])
        // Overflow button of the first grid card: info area starts at 60 + 160 dp, the
        // 40 dp button sits 8 dp above the card bottom at the card's right edge.
        menuApp.menus.show(anchor: CGRect(x: 122, y: 244, width: 40, height: 40),
                           items: [
                               OrMenuItem(label: ProjectDialogStrings.rename),
                               OrMenuItem(label: ProjectDialogStrings.copy),
                               OrMenuItem(label: ProjectDialogStrings.remove),
                           ])
        scenarios.append(SnapshotScenario(
            name: "09-projects-overflow-menu",
            size: portrait,
            title: "Project overflow menu (Rename / Make a copy / Delete)",
            view: rootView(menuApp, size: portrait)
        ))

        let renameApp = DemoProjects.makeApp(projectNames: gridNames, route: [.projects])
        ProjectDialogs.rename(app: renameApp, name: "test-square")
        scenarios.append(SnapshotScenario(
            name: "10-dialog-rename",
            size: portrait,
            title: "Rename file? / Filename / Rename (first project)",
            view: rootView(renameApp, size: portrait)
        ))

        let copyApp = DemoProjects.makeApp(projectNames: gridNames, route: [.projects])
        ProjectDialogs.copy(app: copyApp, name: "test-square")
        scenarios.append(SnapshotScenario(
            name: "11-dialog-copy",
            size: portrait,
            title: "Make a copy? / Cancel / Copy",
            view: rootView(copyApp, size: portrait)
        ))

        let deleteApp = DemoProjects.makeApp(projectNames: gridNames, route: [.projects])
        ProjectDialogs.deleteOne(app: deleteApp, name: "test-square")
        scenarios.append(SnapshotScenario(
            name: "12-dialog-delete",
            size: portrait,
            title: "Delete file? / Cancel / Delete",
            view: rootView(deleteApp, size: portrait)
        ))

        let snackbarApp = DemoProjects.makeApp(projectNames: gridNames, route: [.projects])
        snackbarApp.toast.show(ProjectDialogStrings.renameSuccess)
        scenarios.append(SnapshotScenario(
            name: "13-projects-snackbar",
            size: portrait,
            title: "Snackbar — “File renamed”",
            view: rootView(snackbarApp, size: portrait)
        ))

        // MARK: About
        let aboutApp = DemoProjects.makeApp(projectNames: gridNames, route: [.projects])
        AboutDialog.show(app: aboutApp)
        scenarios.append(SnapshotScenario(
            name: "14-dialog-about",
            size: portrait,
            title: "About dialog (about_text_*)",
            view: rootView(aboutApp, size: portrait)
        ))

        // MARK: Preview
        // Reference `projects-preview.png` / `projects-previewmenu.png`: first project opened
        // (test-square), whose preview shows the seeded CP line art.
        let previewApp = DemoProjects.makeApp(projectNames: DemoProjects.referenceProjectNames,
                                              route: [.projects, .preview(PreviewParams(name: "test-square"))])
        scenarios.append(SnapshotScenario(
            name: "15-preview",
            size: portrait,
            title: "Preview — read-only CP, transparent toolbar, Edit FAB",
            view: rootView(previewApp, size: portrait)
        ))
        let previewMenuApp = DemoProjects.makeApp(projectNames: DemoProjects.referenceProjectNames,
                                                  route: [.projects, .preview(PreviewParams(name: "test-square"))])
        // Preview toolbar overflow button: 48 dp button at the bar's trailing edge.
        previewMenuApp.menus.show(anchor: CGRect(x: 768, y: 4, width: 48, height: 48),
                                  items: [
                                      OrMenuItem(label: ProjectDialogStrings.rename),
                                      OrMenuItem(label: ProjectDialogStrings.copy),
                                      OrMenuItem(label: ProjectDialogStrings.remove),
                                  ])
        scenarios.append(SnapshotScenario(
            name: "16-preview-overflow-menu",
            size: portrait,
            title: "Preview overflow menu (Rename / Make a copy / Delete)",
            view: rootView(previewMenuApp, size: portrait)
        ))

        // MARK: Settings + number picker
        let settingsApp = DemoProjects.makeApp(projectNames: [], route: [.projects, .settings])
        scenarios.append(SnapshotScenario(
            name: "17-settings",
            size: portrait,
            title: "Settings — Drawing / Folded Model preference rows (APK row metrics)",
            view: rootView(settingsApp, size: portrait)
        ))
        let numberApp = DemoProjects.makeApp(projectNames: [], route: [.projects, .settings])
        numberApp.dialogs.numberDialog(title: SettingsStrings.gridDivisionsDialog,
                                       value: Preferences.Default.gridDivisions,
                                       minValue: Preferences.Default.gridMin,
                                       maxValue: Preferences.Default.gridMax,
                                       halfLabel: SettingsStrings.gridHalf,
                                       twiceLabel: SettingsStrings.gridTwice) { _ in }
        scenarios.append(SnapshotScenario(
            name: "18-dialog-number-picker",
            size: portrait,
            title: "Set Grid Row/Column Count (x1/2 / x2, 2…256)",
            view: rootView(numberApp, size: portrait)
        ))

        // MARK: Editor — paint / check / export dialogs (ui-canvas, 19…31)
        scenarios.append(contentsOf: EditorSnapshotSupport.scenarios())

        // MARK: Fold — xray / overlap / cut line + fold dialogs (ui-fold, 40…53)
        scenarios.append(contentsOf: FoldSnapshot.scenarios())

        // `EditorSnapshotSupport`/`FoldSnapshot` call `ORIPACanvasIntegration.install()` while
        // building their scenarios, which replaces the snapshot preview factory above.
        // Re-install it last so 15/16 render the seeded line art in the headless renderer
        // (runtime still uses the ui-canvas factory installed by the app integration).
        installSnapshotPreviewRenderer()

        return scenarios
    }

    // MARK: - Snapshot-only preview renderer

    /// Until the real (ui-canvas) `PreviewRenderer` handles the demo OPXC marker, render the
    /// synthetic demo line art in the preview screen so the snapshot shows a real CP.
    private static func installSnapshotPreviewRenderer() {
        OrScreenRegistry.creasePatternPreviewFactory = { data in
            guard let seed = DemoProjects.seed(from: data) else { return nil }
            return AnyView(DemoProjects.previewView(seed: seed))
        }
    }

    // MARK: - View helpers

    private static func rootView(_ app: AppModel, size: CGSize) -> AnyView {
        AnyView(
            ORIPARootView(app: app)
                .frame(width: size.width, height: size.height)
                .oripaSnapshotMode()
        )
    }

    private static func screenView<Content: View>(_ app: AppModel,
                                                  size: CGSize,
                                                  @ViewBuilder content: () -> Content) -> AnyView {
        AnyView(
            SnapshotScreenHost(app: app, content: content())
                .frame(width: size.width, height: size.height)
                .oripaSnapshotMode()
        )
    }
}

/// Hosts one screen with the same environment objects + global overlays as `ORIPARootView`
/// (used for scenarios that need a specific activity-instance state, e.g. list mode).
public struct SnapshotScreenHost<Content: View>: View {
    private let app: AppModel
    private let content: Content

    public init(app: AppModel, content: Content) {
        self.app = app
        self.content = content
    }

    public var body: some View {
        ZStack {
            OrTheme.primaryDark.ignoresSafeArea()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { OrMenuHost(center: app.menus) }
        .overlay { OrDialogHost(center: app.dialogs) }
        .overlay { SnackbarHost(center: app.toast) }
        .environmentObject(app)
        .environmentObject(app.prefs)
        .environmentObject(app.store)
        .environmentObject(app.fileExchange)
        .environmentObject(app.toast)
        .environmentObject(app.dialogs)
        .environmentObject(app.menus)
        .preferredColorScheme(.light)
    }
}
