// Editor settings (Android default SharedPreferences keys/defaults).
//
// Port of `readSettings()` in `oripa-port/src/js/ui/screens/editor.js` + the keys of
// `res/xml/pref_paint_cp_settings.xml` / `res/values/integers.xml`. The editor applies
// this snapshot to the renderers on entry and on `resume()` (return from Settings).
import Foundation

/// Parsed paint/fold settings used by the editor session and the renderers.
public struct EditorSettings: Equatable {
    public var showGrid: Bool = true
    public var gridDivisions: Int = 4
    public var gridType: Int = 0          // GridType.SQUARE ("0") / TRIANGLE ("1")
    public var showMvbLines: Bool = true
    public var showFlatLines: Bool = true
    public var showVertices: Bool = true
    public var useDashedLines: Bool = false
    public var directSelection: Bool = true
    public var foldOverlap: Bool = true
    public var foldOverlapShadow: Bool = false

    /// The renderer also accepts the `showMVBLines` spelling (PaintRenderer.setPreferences).
    public var showMVBLines: Bool { showMvbLines }

    public init() {}

    /// `PaintRenderer.setPreferences` payload.
    public var paintPreferences: PaintRenderPreferences {
        PaintRenderPreferences(showGrid: showGrid,
                               gridDivisions: gridDivisions,
                               gridType: gridType,
                               showMvbLines: showMvbLines,
                               showFlatLines: showFlatLines,
                               showVertices: showVertices,
                               useDashedLines: useDashedLines)
    }
}

@MainActor
public enum EditorPrefs {
    /// `readSettings()`; every read falls back to the Android default when unset.
    public static func read(_ prefs: Preferences) -> EditorSettings {
        var settings = EditorSettings()
        settings.showGrid = prefs.bool(Preferences.Key.showGrid, default: true)
        settings.gridDivisions = prefs.int(Preferences.Key.gridDivisions, default: 4)
        settings.gridType = prefs.int(Preferences.Key.gridType, default: 0)
        settings.showMvbLines = prefs.bool(Preferences.Key.showMvbLines, default: true)
        settings.showFlatLines = prefs.bool(Preferences.Key.showFlatLines, default: true)
        settings.showVertices = prefs.bool(Preferences.Key.showVertices, default: true)
        settings.useDashedLines = prefs.bool(Preferences.Key.useDashedLines, default: false)
        settings.directSelection = prefs.bool(Preferences.Key.directSelection, default: true)
        settings.foldOverlap = prefs.bool(Preferences.Key.foldOverlap, default: true)
        settings.foldOverlapShadow = prefs.bool(Preferences.Key.foldOverlapShadow, default: false)
        return settings
    }

    /// Paint-screen menu state (PaintCpFragment pref keys, Java R.id ints).
    public struct PaintMenuState: Equatable {
        public var drawAction: Int
        public var addMethod: Int
        public var addLineType: Int
        public var changeFrom: Int
        public var changeTo: Int
        public var deleteType: Int

        public init(drawAction: Int = PaintTools.PrefDefault.drawAction,
                    addMethod: Int = PaintTools.PrefDefault.addMethod,
                    addLineType: Int = PaintTools.PrefDefault.addLineType,
                    changeFrom: Int = PaintTools.PrefDefault.changeLineTypeFrom,
                    changeTo: Int = PaintTools.PrefDefault.changeLineTypeTo,
                    deleteType: Int = PaintTools.PrefDefault.deleteLineType) {
            self.drawAction = drawAction
            self.addMethod = addMethod
            self.addLineType = addLineType
            self.changeFrom = changeFrom
            self.changeTo = changeTo
            self.deleteType = deleteType
        }
    }

    /// Reads the persisted paint menu ids (`PaintCpFragment.*` keys).
    public static func readMenuState(_ prefs: Preferences) -> PaintMenuState {
        PaintMenuState(
            drawAction: prefs.int(PaintTools.PrefKey.drawAction, default: PaintTools.PrefDefault.drawAction),
            addMethod: prefs.int(PaintTools.PrefKey.addMethod, default: PaintTools.PrefDefault.addMethod),
            addLineType: prefs.int(PaintTools.PrefKey.addLineType, default: PaintTools.PrefDefault.addLineType),
            changeFrom: prefs.int(PaintTools.PrefKey.changeLineTypeFrom, default: PaintTools.PrefDefault.changeLineTypeFrom),
            changeTo: prefs.int(PaintTools.PrefKey.changeLineTypeTo, default: PaintTools.PrefDefault.changeLineTypeTo),
            deleteType: prefs.int(PaintTools.PrefKey.deleteLineType, default: PaintTools.PrefDefault.deleteLineType))
    }

    /// Persists one of the paint menu ids (`setPref` in paint.js).
    public static func setMenuPref(_ prefs: Preferences, key: String, value: Int) {
        prefs.setInt(value, for: key)
    }
}
