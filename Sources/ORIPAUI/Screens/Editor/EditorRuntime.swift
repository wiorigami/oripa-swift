// Editor screen runtime: owns the retained session and the per-fragment state objects
// (the port of the retained fragments of `editor/EditorActivity`).
//
// `EditorScreen` is a thin SwiftUI shell around this runtime; keeping the mutable state in
// one `@StateObject` mirrors the JS contract that the session + renderers survive
// fragment switches and Settings round-trips.
import Foundation
import SwiftUI
import ORIPACore

@MainActor
final class EditorRuntime: ObservableObject {
    let session: EditorSession
    let menu: PaintMenuModel
    let paintRenderer: PaintRenderer
    let checkRenderer: CheckRenderer
    let paintDriver: PaintDriver
    let paintCoordinator: PaintCoordinator
    let checkCoordinator: CheckCoordinator

    /// Back-handler re-entrancy flags (editor.js `inBackHandler` / `exitRequested`).
    var inBackHandler = false
    var exitRequested = false

    init(params: EditorParams, app: AppModel) {
        let session = EditorSession(params: params, app: app)
        let menu = PaintMenuModel(prefs: app.prefs)
        let paintRenderer = PaintRenderer()
        let checkRenderer = CheckRenderer()
        let driver = PaintDriver(session: session, menu: menu, renderer: paintRenderer)
        let paintCoordinator = PaintCoordinator(session: session, menu: menu, driver: driver,
                                                renderer: paintRenderer, app: app)
        let checkCoordinator = CheckCoordinator(session: session, renderer: checkRenderer, app: app)

        self.session = session
        self.menu = menu
        self.paintRenderer = paintRenderer
        self.checkRenderer = checkRenderer
        self.paintDriver = driver
        self.paintCoordinator = paintCoordinator
        self.checkCoordinator = checkCoordinator

        // cp edit / undo / redo -> repaint (the paint screen's refreshLinesPoints()).
        session.onContentChanged = { [weak driver] in
            driver?.refreshRenderData()
        }
    }
}
