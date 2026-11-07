// Paint-screen tool tables, Android resource ids and UI strings.
//
// Port of the tables at the top of `oripa-port/src/js/ui/fragments/paint.js` (which came
// from `res/menu/paint_cp_*.xml`, `PaintCpFragment.java` and `values/strings.xml`).
// The R.id integer values are persisted in the Android default SharedPreferences
// (`PaintCpFragment.drawAction` etc.) and the core state machines read them back through
// the CpContext adapter, so they must stay exactly as in the reference.
import Foundation

// MARK: - Actions

public enum PaintActionKind: String {
    case add
    case change
    case select
    case delete
    case deleteVertex
}

public struct PaintActionItem: Identifiable, Equatable {
    public var id: Int
    public var icon: String
    public var title: String
    public var action: PaintActionKind
}

public struct PaintMethodItem: Identifiable, Equatable {
    public var id: Int
    public var icon: String
    public var title: String
    /// Core state machine class name (JS `O[ctor]`).
    public var machineName: String
}

public struct PaintLineTypeItem: Identifiable, Equatable {
    public var id: Int
    public var icon: String
    public var title: String
    public var condensed: String?
    /// LineType raw value.
    public var type: Int
}

public struct PaintChangeItem: Identifiable, Equatable {
    public var id: Int
    public var icon: String
    public var title: String
    public var condensed: String?
    /// nil = "Any" (no filter); "flip" handled by caller for the To list.
    public var type: Int?
    public var isFlip: Bool = false
}

public struct PaintDeleteTypeItem: Identifiable, Equatable {
    public var id: Int
    public var icon: String
    public var title: String
    public var condensed: String?
    public var type: Int?
}

public enum PaintTools {
    // MARK: Java R.id values (paint_cp_action_bar / paint_cp_top_bar / paint_cp_fab_mini menues)

    public enum Id {
        public static let actionAddLine = 0x7f09008c
        public static let actionChangeLine = 0x7f09008d
        public static let actionDeleteLine = 0x7f09008e
        public static let actionDeleteVertex = 0x7f09008f
        public static let actionSelectLine = 0x7f090090
        public static let addClearSelection = 0x7f090091
        public static let addLineGroup = 0x7f090092
        public static let methodBisector = 0x7f090093
        public static let methodByValue = 0x7f090094
        public static let methodExtendedLine = 0x7f090095
        public static let methodIncenter = 0x7f090096
        public static let methodLine = 0x7f090097
        public static let methodMirror = 0x7f090098
        public static let methodPbisector = 0x7f090099
        public static let methodPsegment = 0x7f09009a
        public static let methodSegment = 0x7f09009b
        public static let methodSymmetrical = 0x7f09009c
        public static let addTypeBoundary = 0x7f09009d
        public static let addTypeFlat = 0x7f09009e
        public static let addTypeMountain = 0x7f09009f
        public static let addTypeValley = 0x7f0900a0
        public static let allActions = 0x7f0900a1
        public static let allAddLineTypes = 0x7f0900a2
        public static let allAddMethods = 0x7f0900a3
        public static let allChangeFrom = 0x7f0900a4
        public static let allChangeTo = 0x7f0900a5
        public static let allDeleteLineTypes = 0x7f0900a6
        public static let changeLineGroup = 0x7f0900a7
        public static let changeTransition = 0x7f0900a8
        public static let changeFromAny = 0x7f0900a9
        public static let changeFromBoundary = 0x7f0900aa
        public static let changeFromFlat = 0x7f0900ab
        public static let changeFromMountain = 0x7f0900ac
        public static let changeFromValley = 0x7f0900ad
        public static let changeToBoundary = 0x7f0900ae
        public static let changeToFlat = 0x7f0900af
        public static let changeToFlip = 0x7f0900b0
        public static let changeToMountain = 0x7f0900b1
        public static let changeToValley = 0x7f0900b2
        public static let deleteLineGroup = 0x7f0900b3
        public static let deleteAny = 0x7f0900b4
        public static let deleteBoundary = 0x7f0900b5
        public static let deleteFlat = 0x7f0900b6
        public static let deleteMountain = 0x7f0900b7
        public static let deleteValley = 0x7f0900b8
        public static let help = 0x7f0900b9
        public static let hideMenus = 0x7f0900ba
        public static let redo = 0x7f0900bb
        public static let selectDeleteSelected = 0x7f0900bc
        public static let selectDeselectAll = 0x7f0900bd
        public static let selectLineGroup = 0x7f0900be
        public static let selectSelectAll = 0x7f0900bf
        public static let settings = 0x7f0900c0
        public static let toggleDrawTools = 0x7f0900c1
        public static let undo = 0x7f0900c2
    }

    // MARK: Private preference keys (Android default SharedPreferences)

    public enum PrefKey {
        public static let drawAction = "PaintCpFragment.drawAction"
        public static let addMethod = "PaintCpFragment.addMethod"
        public static let addLineType = "PaintCpFragment.addLineType"
        public static let changeLineTypeFrom = "PaintCpFragment.changeLineTypeFrom"
        public static let changeLineTypeTo = "PaintCpFragment.changeLineTypeTo"
        public static let deleteLineType = "PaintCpFragment.deleteLineType"
    }

    public enum PrefDefault {
        public static let drawAction = Id.actionAddLine
        public static let addMethod = Id.methodSegment
        public static let addLineType = Id.addTypeMountain
        public static let changeLineTypeFrom = Id.changeFromAny
        public static let changeLineTypeTo = Id.changeToMountain
        public static let deleteLineType = Id.deleteAny
    }

    // MARK: Tables

    public static let actions: [PaintActionItem] = [
        PaintActionItem(id: Id.actionAddLine, icon: "ic_brush_dark_24dp", title: PaintStrings.addActionTitle, action: .add),
        PaintActionItem(id: Id.actionChangeLine, icon: "ic_line_style_dark_24dp", title: PaintStrings.changeActionTitle, action: .change),
        PaintActionItem(id: Id.actionSelectLine, icon: "ic_touch_app_dark_24dp", title: PaintStrings.selectActionTitle, action: .select),
        PaintActionItem(id: Id.actionDeleteLine, icon: "ic_content_cut_dark_24dp", title: PaintStrings.deleteActionTitle, action: .delete),
        PaintActionItem(id: Id.actionDeleteVertex, icon: "ic_remove_circle_dark_24dp", title: PaintStrings.deleteVertexTitle, action: .deleteVertex),
    ]

    public static let methods: [PaintMethodItem] = [
        PaintMethodItem(id: Id.methodSegment, icon: "ic_oripa_segment_v2", title: "Segment", machineName: "AddSegmentSM"),
        PaintMethodItem(id: Id.methodLine, icon: "ic_oripa_line_v3", title: "Line", machineName: "AddLineSM"),
        PaintMethodItem(id: Id.methodPbisector, icon: "ic_oripa_pbisector_v3", title: "Perpendicular Bisector", machineName: "AddPerpendicularBisectorSM"),
        PaintMethodItem(id: Id.methodBisector, icon: "ic_oripa_bisector_v2", title: "Angle Bisector", machineName: "AddAngleBisectorSM"),
        PaintMethodItem(id: Id.methodIncenter, icon: "ic_oripa_incenter_v2", title: "Incenter", machineName: "AddTriangleIncenterSM"),
        PaintMethodItem(id: Id.methodPsegment, icon: "ic_oripa_vertical_v2", title: "Perpendicular Segment", machineName: "AddPerpendicularSegmentSM"),
        PaintMethodItem(id: Id.methodSymmetrical, icon: "ic_oripa_symmetry_v2", title: "Symmetrical Segment", machineName: "AddSymmetricalSegmentSM"),
        PaintMethodItem(id: Id.methodExtendedLine, icon: "ic_oripa_extend_line_v2", title: "Line Extension", machineName: "AddLineExtensionSM"),
        PaintMethodItem(id: Id.methodMirror, icon: "ic_oripa_mirror_v2", title: "Mirror Copy", machineName: "AddMirroredLinesSM"),
        PaintMethodItem(id: Id.methodByValue, icon: "ic_oripa_by_value_v2", title: "Segment by Value", machineName: ""),
    ]

    /// LineType raw values: FLAT 0, BOUNDARY 1, MOUNTAIN 2, VALLEY 3.
    public static let lineTypes: [PaintLineTypeItem] = [
        PaintLineTypeItem(id: Id.addTypeMountain, icon: "ic_oripa_line_mountain", title: "Mountain", condensed: "M", type: 2),
        PaintLineTypeItem(id: Id.addTypeValley, icon: "ic_oripa_line_valley", title: "Valley", condensed: "V", type: 3),
        PaintLineTypeItem(id: Id.addTypeFlat, icon: "ic_oripa_line_flat", title: "Flat", condensed: "F", type: 0),
        PaintLineTypeItem(id: Id.addTypeBoundary, icon: "ic_oripa_line_boundary", title: "Boundary", condensed: "B", type: 1),
    ]

    public static let changeFrom: [PaintChangeItem] = [
        PaintChangeItem(id: Id.changeFromAny, icon: "ic_oripa_line_any", title: "Any", type: nil),
        PaintChangeItem(id: Id.changeFromMountain, icon: "ic_oripa_line_mountain", title: "Mountain", condensed: "M", type: 2),
        PaintChangeItem(id: Id.changeFromValley, icon: "ic_oripa_line_valley", title: "Valley", condensed: "V", type: 3),
        PaintChangeItem(id: Id.changeFromFlat, icon: "ic_oripa_line_flat", title: "Flat", condensed: "F", type: 0),
        PaintChangeItem(id: Id.changeFromBoundary, icon: "ic_oripa_line_boundary", title: "Boundary", condensed: "B", type: 1),
    ]

    public static let changeTo: [PaintChangeItem] = [
        PaintChangeItem(id: Id.changeToMountain, icon: "ic_oripa_line_mountain", title: "Mountain", condensed: "M", type: 2),
        PaintChangeItem(id: Id.changeToValley, icon: "ic_oripa_line_valley", title: "Valley", condensed: "V", type: 3),
        PaintChangeItem(id: Id.changeToFlat, icon: "ic_oripa_line_flat", title: "Flat", condensed: "F", type: 0),
        PaintChangeItem(id: Id.changeToBoundary, icon: "ic_oripa_line_boundary", title: "Boundary", condensed: "B", type: 1),
        PaintChangeItem(id: Id.changeToFlip, icon: "ic_oripa_line_flip", title: "Flip M/V", condensed: "Flip", type: nil, isFlip: true),
    ]

    public static let deleteTypes: [PaintDeleteTypeItem] = [
        PaintDeleteTypeItem(id: Id.deleteAny, icon: "ic_oripa_line_any", title: "Any", type: nil),
        PaintDeleteTypeItem(id: Id.deleteMountain, icon: "ic_oripa_line_mountain", title: "Mountain", condensed: "M", type: 2),
        PaintDeleteTypeItem(id: Id.deleteValley, icon: "ic_oripa_line_valley", title: "Valley", condensed: "V", type: 3),
        PaintDeleteTypeItem(id: Id.deleteFlat, icon: "ic_oripa_line_flat", title: "Flat", condensed: "F", type: 0),
        PaintDeleteTypeItem(id: Id.deleteBoundary, icon: "ic_oripa_line_boundary", title: "Boundary", condensed: "B", type: 1),
    ]

    /// By-value spinner entries (`draw_method_by_value_container`).
    public enum ByValueEntry: Int, CaseIterable {
        case getAngle = 0
        case getLength = 1
        case drawLine = 2

        public var icon: String {
            switch self {
            case .getAngle: return "ic_oripa_segment_v2"
            case .getLength: return "ic_oripa_segment_v2"
            case .drawLine: return "ic_oripa_by_value_v2"
            }
        }

        public var label: String {
            switch self {
            case .getAngle: return "Get Angle"
            case .getLength: return "Get Length"
            case .drawLine: return "Draw Line"
            }
        }

        /// Core state machine name (`setCurrentStateMachineAddLineByValue`).
        public var machineName: String {
            switch self {
            case .getAngle: return "AddSegmentByValueGetAngleSM"
            case .getLength: return "AddSegmentByValueGetLengthSM"
            case .drawLine: return "AddSegmentByValueDrawLineSM"
            }
        }
    }

    // MARK: Lookup helpers (findById: first entry is the fallback)

    public static func action(_ id: Int) -> PaintActionItem { find(actions, id) ?? actions[0] }
    public static func method(_ id: Int) -> PaintMethodItem { find(methods, id) ?? methods[0] }
    public static func lineType(_ id: Int) -> PaintLineTypeItem { find(lineTypes, id) ?? lineTypes[0] }
    public static func changeFromItem(_ id: Int) -> PaintChangeItem { find(changeFrom, id) ?? changeFrom[0] }
    public static func changeToItem(_ id: Int) -> PaintChangeItem { find(changeTo, id) ?? changeTo[0] }
    public static func deleteTypeItem(_ id: Int) -> PaintDeleteTypeItem { find(deleteTypes, id) ?? deleteTypes[0] }

    private static func find<T: Identifiable>(_ list: [T], _ id: Int) -> T? where T.ID == Int {
        list.first { $0.id == id }
    }
}

// MARK: - UI strings (values/strings.xml via the JS port)

public enum PaintStrings {
    // paint_cp_action_bar.xml
    public static let toggleDrawTools = "Toggle Draw Tools"
    public static let undo = "Undo"
    public static let redo = "Redo"
    public static let settings = "Settings"
    public static let hideMenus = "Hide Menus"
    public static let showMenus = "Show Menus"
    public static let navigateUp = "Navigate up"

    // paint_cp_fab_mini.xml
    public static let fabDescription = "CP Options"
    public static let fabExport = "Export"
    public static let fabFold = "Fold"
    public static let fabCheck = "Check"

    // paint_cp_top_bar.xml
    public static let allActions = "Action"
    public static let addActionTitle = "Add Line"
    public static let changeActionTitle = "Change Line"
    public static let selectActionTitle = "Select Line"
    public static let deleteActionTitle = "Delete Line"
    public static let deleteVertexTitle = "Clean Vertex"
    public static let addMethodTitle = "Add Line Method"
    public static let addMethodCondensed = "Method"
    public static let lineTypeTitle = "Line Type"
    public static let fromTitle = "From"
    public static let toTitle = "To"
    public static let transitionTitle = "change to"
    public static let clearSelection = "Clear Selection"
    public static let clearSelectionCondensed = "Clr"
    public static let selectAll = "Select All"
    public static let deselectAll = "Deselect All"
    public static let deleteSelected = "Delete Selected"
    public static let help = "Help"
    public static let moreOptions = "More options"

    // dialogs / strings.xml
    public static let angleDialogTitle = "Set Angle (Degrees)"
    public static let angleDialogHint = "Degrees"
    public static let lengthDialogTitle = "Set Length"
    public static let lengthDialogHint = "Length"
    public static let ok = "OK"
    public static let cancel = "Cancel"
    public static let close = "Close"
    public static let attention = "Attention"
    public static let saveChangesTitle = "Save changes?"
    public static let save = "Save"
    public static let discard = "Discard"
    public static let saveCurrent = "Save to current file"
    public static let saveNew = "Save to new file"

    public static let checkTitle = "Local Flat Foldability"
    public static let untitled = "untitled"
    public static let featureUnderConstruction = "Feature under construction.\n\nThank you for your patience!"
    public static let foldError = "Cannot fold. The pattern has basic problems. Please check the pattern again and address any issues."

    // Export CP dialog (paint_dialog_export_title / cp_dialog_export_positive_button /
    // dialog_export_png_square_* / message_download_*)
    public static let exportTitle = "Export Crease Pattern"
    public static let exportPositive = "Export"
    public static let pngOptionsTitle = "PNG Options"
    public static let pngDimensionText = "Image size (pixels):"
    public static let downloadSuccess = "Download complete"
    public static let downloadSuccessAction = "View folder"
    public static let downloadFail = "Download failed"

    // Editor title strings (editor.js)
    public static let loading = "Loading…"

    // Number formatting helpers
    public static func formatNumber(_ n: Double) -> String {
        if n.isNaN { return "0" }
        let rounded = (n * 1e9).rounded() / 1e9
        if rounded == rounded.rounded() && abs(rounded) < 1e15 {
            return String(Int64(rounded))
        }
        return String(rounded)
    }

    public static func parseNumber(_ text: String) -> Double {
        let cleaned = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }
}
