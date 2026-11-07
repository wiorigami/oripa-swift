// Settings screen — port of `PaintCpSettingsActivity` + `res/xml/pref_paint_cp_settings.xml`.
//
// Rebuilds the Android PreferenceFragment as the same Material preference list:
//   Drawing:      Show Grid / Grid Division Number / Grid Type / Show Crease/Boundary Lines /
//                 Show Flat Lines / Show Vertices / Use Dashed Lines / Use Direct Selection Mode
//   Folded Model: Enable Overlap View [BETA] / Show Overlap Shadow [BETA]
//
// Preference keys are the exact Android string resource values and the values are stored in
// the Android-compatible `Preferences` store (UserDefaults `oripa.pref.*`). The editor
// re-reads them when it resumes (`PaintCpFragment.onActivityResult`).
import SwiftUI

public struct SettingsScreen: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.oripaNavID) private var navID

    // Preference values, loaded on appear (the screen is rebuilt on resume like Android).
    @State private var showGrid = true
    @State private var gridDivisions = Preferences.Default.gridDivisions
    @State private var gridType = "0"
    @State private var showMvbLines = true
    @State private var showFlatLines = true
    @State private var showVertices = true
    @State private var useDashedLines = false
    @State private var directSelection = true
    @State private var foldOverlap = true
    @State private var foldOverlapShadow = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            OrToolbar(title: SettingsStrings.title)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    drawingSection
                    foldedModelSection
                    Color.clear.frame(height: 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrTheme.background)
        .onAppear { load() }
        .onChange(of: app.navigation.last?.id) { topID in
            // `resume()`: rebuild after being uncovered (settings could be covered by a
            // future sub-screen; Android rebuilds the preference list as well).
            if topID == navID { load() }
        }
    }

    // MARK: - Drawing

    private var drawingSection: some View {
        VStack(spacing: 0) {
            OrPreferenceCategory(SettingsStrings.catDraw)
            OrSwitchRow(title: SettingsStrings.showGrid,
                        iconOn: "ic_grid_on_dark_24dp",
                        iconOff: "ic_grid_off_dark_24dp",
                        isOn: Binding(
                            get: { showGrid },
                            set: { newValue in
                                showGrid = newValue
                                app.prefs.setBool(newValue, for: Preferences.Key.showGrid)
                            }
                        ))
            OrListPreferenceRow(title: SettingsStrings.gridDivisions,
                                summary: String(gridDivisions),
                                isEnabled: showGrid) {
                showGridDivisionsDialog()
            }
            OrListPreferenceRow(title: SettingsStrings.gridType,
                                summary: gridTypeLabel,
                                isEnabled: showGrid) {
                showGridTypeDialog()
            }
            switchRow(title: SettingsStrings.showMvb,
                      iconOn: "ic_visibility_dark_24dp",
                      iconOff: "ic_visibility_off_dark_24dp",
                      key: Preferences.Key.showMvbLines,
                      value: $showMvbLines)
            switchRow(title: SettingsStrings.showFlat,
                      iconOn: "ic_visibility_dark_24dp",
                      iconOff: "ic_visibility_off_dark_24dp",
                      key: Preferences.Key.showFlatLines,
                      value: $showFlatLines)
            switchRow(title: SettingsStrings.showVertices,
                      iconOn: "ic_visibility_dark_24dp",
                      iconOff: "ic_visibility_off_dark_24dp",
                      key: Preferences.Key.showVertices,
                      value: $showVertices)
            switchRow(title: SettingsStrings.useDashed,
                      iconOn: "ic_line_style_dark_24dp",
                      iconOff: "ic_line_weight_dark_inactive_24dp",
                      key: Preferences.Key.useDashedLines,
                      value: $useDashedLines)
            switchRow(title: SettingsStrings.directSelection,
                      summary: SettingsStrings.directSelectionSummary,
                      key: Preferences.Key.directSelection,
                      value: $directSelection)
        }
    }

    // MARK: - Folded Model

    private var foldedModelSection: some View {
        VStack(spacing: 0) {
            OrPreferenceCategory(SettingsStrings.catFold)
            switchRow(title: SettingsStrings.foldOverlap,
                      key: Preferences.Key.foldOverlap,
                      value: $foldOverlap)
            switchRow(title: SettingsStrings.foldOverlapShadow,
                      key: Preferences.Key.foldOverlapShadow,
                      value: $foldOverlapShadow,
                      isEnabled: foldOverlap)
        }
    }

    // MARK: - Rows

    private func switchRow(title: String,
                           summary: String? = nil,
                           iconOn: String? = nil,
                           iconOff: String? = nil,
                           key: String,
                           value: Binding<Bool>,
                           isEnabled: Bool = true) -> some View {
        OrSwitchRow(
            title: title,
            summary: summary,
            iconOn: iconOn,
            iconOff: iconOff,
            isOn: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    value.wrappedValue = newValue
                    app.prefs.setBool(newValue, for: key)
                }
            ),
            isEnabled: isEnabled
        )
    }

    // MARK: - Dialogs

    private func showGridDivisionsDialog() {
        app.dialogs.numberDialog(
            title: SettingsStrings.gridDivisionsDialog,
            value: gridDivisions,
            minValue: Preferences.Default.gridMin,
            maxValue: Preferences.Default.gridMax,
            halfLabel: SettingsStrings.gridHalf,
            twiceLabel: SettingsStrings.gridTwice,
            positiveText: CommonDialogStrings.ok,
            negativeText: CommonDialogStrings.cancel
        ) { newValue in
            guard let newValue else { return }
            gridDivisions = newValue
            app.prefs.setInt(newValue, for: Preferences.Key.gridDivisions)
        }
    }

    private func showGridTypeDialog() {
        let items = [
            OrChoiceItem(label: SettingsStrings.gridSquare, icon: "ic_crop_din_dark_24dp"),
            OrChoiceItem(label: SettingsStrings.gridTriangle, icon: "ic_change_history_dark_24dp"),
        ]
        let selected = gridType == "1" ? 1 : 0
        app.dialogs.singleChoice(title: SettingsStrings.gridTypeDialog,
                                 items: items,
                                 selectedIndex: selected) { index in
            let value = index == 1 ? "1" : "0"
            gridType = value
            app.prefs.setString(value, for: Preferences.Key.gridType)
        }
    }

    // MARK: - State

    private var gridTypeLabel: String {
        gridType == "1" ? SettingsStrings.gridTriangle : SettingsStrings.gridSquare
    }

    private func load() {
        showGrid = app.prefs.bool(Preferences.Key.showGrid, default: true)
        gridDivisions = app.prefs.int(Preferences.Key.gridDivisions,
                                      default: Preferences.Default.gridDivisions)
        gridType = app.prefs.string(Preferences.Key.gridType, default: "0")
        showMvbLines = app.prefs.bool(Preferences.Key.showMvbLines, default: true)
        showFlatLines = app.prefs.bool(Preferences.Key.showFlatLines, default: true)
        showVertices = app.prefs.bool(Preferences.Key.showVertices, default: true)
        useDashedLines = app.prefs.bool(Preferences.Key.useDashedLines, default: false)
        directSelection = app.prefs.bool(Preferences.Key.directSelection, default: true)
        foldOverlap = app.prefs.bool(Preferences.Key.foldOverlap, default: true)
        foldOverlapShadow = app.prefs.bool(Preferences.Key.foldOverlapShadow, default: false)
    }
}

// MARK: - Strings (`res/values/strings.xml` + `arrays.xml`)

/// Settings screen strings — exact resource values.
public enum SettingsStrings {
    public static let title = "Settings"                                    // paint_cp_settings_title
    public static let catDraw = "Drawing"                                   // paint_pref_cat_draw_title
    public static let catFold = "Folded Model"                              // paint_pref_cat_fold_title
    public static let showGrid = "Show Grid"                                // paint_pref_show_grid_title
    public static let gridDivisions = "Grid Division Number"                // paint_pref_grid_divisions_title
    public static let gridDivisionsDialog = "Set Grid Row/Column Count"     // paint_pref_grid_divisions_dialog_title
    public static let gridHalf = "x1/2"                                     // paint_pref_grid_divisions_half
    public static let gridTwice = "x2"                                      // paint_pref_grid_divisions_twice
    public static let gridType = "Grid Type"                                // paint_pref_grid_type_title
    public static let gridTypeDialog = "Set Grid Type"                      // paint_pref_grid_type_dialog_title
    public static let showMvb = "Show Crease/Boundary Lines"                // paint_pref_show_mvb_lines_title
    public static let showFlat = "Show Flat Lines"                          // paint_pref_show_flat_lines_title
    public static let showVertices = "Show Vertices"                        // paint_pref_show_vertices_title
    public static let useDashed = "Use Dashed Lines"                        // paint_pref_use_dashed_lines_title
    public static let directSelection = "Use Direct Selection Mode"         // paint_pref_direct_selection_title
    public static let directSelectionSummary = "Tap once instead of twice to select points/lines" // ..._summary
    public static let foldOverlap = "Enable Overlap View [BETA]"            // paint_pref_fold_overlap_title
    public static let foldOverlapShadow = "Show Overlap Shadow [BETA]"      // paint_pref_fold_overlap_shadow_title

    /// `arrays.xml paint_pref_grid_type_entries` / `entry_icons`.
    public static let gridSquare = "square"
    public static let gridTriangle = "triangle"
}
