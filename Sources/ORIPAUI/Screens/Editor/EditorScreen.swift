// The editor screen: `EditorActivity` + the retained fragment container.
//
// Port of `oripa-port/src/js/ui/screens/editor.js`:
//   * creates the retained `EditorSession` (ProjectDataFragment) from the `EditorParams`
//     (internal OPXC project / New File / staged external import),
//   * shows exactly one fragment (paint / check / fold), while keeping the paint fragment
//     and its renderers alive (Android retained fragment state),
//   * back semantics with the re-entrancy guard: a save/discard dialog or the check/fold
//     fragment consumes back; `cleanAndExit()` inside the handler lets the router pop once,
//   * crash-safe temp autosave on background/inactive/leave.
//
// The screen is registered by ui-shell through `OrScreenRegistry.editorScreenFactory`
// (see `ORIPACanvasIntegration.install()`), exactly like the JS `ui.registerScreen("editor")`.
import Foundation
import SwiftUI
import ORIPACore

public struct EditorScreen: View {
    @ObservedObject private var app: AppModel
    @StateObject private var runtime: EditorRuntime
    @Environment(\.oripaNavID) private var navID
    @Environment(\.scenePhase) private var scenePhase

    private let params: EditorParams

    public init(params: EditorParams, app: AppModel) {
        self.params = params
        self._app = ObservedObject(wrappedValue: app)
        self._runtime = StateObject(wrappedValue: EditorRuntime(params: params, app: app))
    }

    public var body: some View {
        ZStack {
            // The paint fragment is retained for the whole editor lifetime (editor.js
            // createFragment caches it); it is drawn beneath check/fold when those are open.
            PaintScreen(session: runtime.session,
                        menu: runtime.menu,
                        driver: runtime.paintDriver,
                        renderer: runtime.paintRenderer,
                        app: app,
                        coordinator: runtime.paintCoordinator)
                .opacity(runtime.session.fragment == .paint ? 1 : 0)
                .allowsHitTesting(runtime.session.fragment == .paint)

            if runtime.session.fragment == .check {
                CheckScreen(session: runtime.session,
                            renderer: runtime.checkRenderer,
                            app: app,
                            coordinator: runtime.checkCoordinator)
                    .transition(.opacity)
            }

            if runtime.session.fragment == .fold {
                FoldScreen(session: runtime.session, app: app)
                    .transition(.opacity)
            }
        }
        .background(Color.white)
        .onAppear {
            wireSession()
        }
        .onChange(of: app.navigation) { _ in
            // Returning from a covered screen (e.g. Settings) is the Android onResume:
            // PaintCpFragment.onActivityResult -> re-read preferences.
            if app.topEntry?.id == navID {
                runtime.paintCoordinator.applySettings()
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background, .inactive:
                runtime.session.autosaveTemp()
            default:
                break
            }
        }
        .onDisappear {
            removeBackHandler()
            // Screen removed without going through cleanAndExit: autosave then exit.
            if !runtime.session.closed {
                runtime.session.autosaveTemp()
                runtime.session.markClosedForTeardown()
                app.prefs.clear()
                app.store.deleteTempSave()
            }
        }
    }

    // MARK: - Wiring

    private func wireSession() {
        let session = runtime.session
        session.onClosed = { [weak app, weak runtime] in
            // cleanAndExit() ran inside the back handler: the router pops the editor itself
            // (editor.js inBackHandler/exitRequested), so don't pop twice.
            if runtime?.inBackHandler == true {
                runtime?.exitRequested = true
                return
            }
            app?.pop()
        }

        // Android back: the current fragment's onBack handler, exactly like
        // EditorScreen.onBack in the JS port. Returns true when the event was consumed.
        app.setBackHandler(for: navID) { [weak runtime] in
            guard let runtime else { return false }
            return EditorScreen.handleBack(runtime: runtime, app: app)
        }

        if let error = session.entryError {
            app.dialogs.alert(title: PaintStrings.featureUnderConstruction, message: error)
        }
    }

    private func removeBackHandler() {
        app.removeBackHandler(for: navID)
    }

    /// Port of `EditorScreen.onBack` from editor.js.
    private static func handleBack(runtime: EditorRuntime, app: AppModel) -> Bool {
        let session = runtime.session
        if session.closed { return false }   // already cleaned up: let the router pop
        runtime.inBackHandler = true
        defer { runtime.inBackHandler = false }

        if app.dialogs.isPresented {
            app.dialogs.closeTop()
            return true
        }
        if app.menus.isOpen {
            app.menus.dismiss()
            return true
        }

        switch session.fragment {
        case .check, .fold:
            session.returnToPaint()
        case .paint:
            session.closeProject()
        }

        // cleanAndExit() ran inside the handler (unmodified project / discard):
        // returning false makes the router pop this screen exactly once.
        if session.closed || runtime.exitRequested { return false }
        return true
    }
}
