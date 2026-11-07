// One renderable QA scenario for the headless snapshot tool.
//
// `ORIPAUI.SnapshotScenarios` (owned by the ui-shell workstream) is the source of
// the scenario list; this file adapts it to the minimal shape the CLI needs and keeps
// the tool independent of the UI workstream's evolving scenario fields.
//
// The tool renders every scenario headlessly with ImageRenderer; no window server is
// required, so the same list drives local visual QA and the CI snapshots artifact.
import SwiftUI
import ORIPAUI

struct SnapshotItem {
    /// Stable slug used for the PNG filename (e.g. "01-splash.png").
    let name: String
    /// Render size in points (portrait 820x1180 / landscape 1180x820, matching the
    /// reference screenshots).
    let size: CGSize
    /// The fully wired screen to render (environment objects + overlays included).
    let view: AnyView
}

enum SnapshotCatalog {
    /// All scenarios to render. Called on the main actor because SwiftUI views (and
    /// `ImageRenderer`) are main-actor bound.
    ///
    /// `makeAll()` (not the cached `all`) is used so every CLI run starts from fresh
    /// AppModel/ProjectStore instances — rendering the same scenario twice in one
    /// process must not share mutated dialog/menu state.
    @MainActor
    static func all() -> [SnapshotItem] {
        SnapshotScenarios.makeAll().map { scenario in
            SnapshotItem(name: scenario.name, size: scenario.size, view: scenario.view)
        }
    }
}
