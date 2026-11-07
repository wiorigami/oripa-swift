// The paint-crease-pattern tool driver: the bridge between the touch gestures /
// toolbars and the core state machines.
//
// Port of the touch-handling + history parts of
// `oripa-port/src/js/ui/fragments/paint.js` (which rebuilt
// PaintCpFragment + GLSurfaceViewPaintCp):
//
//   tap          -> StateMachineManager.doTransition(cp, snap, PointDouble, radius)
//                   result 0 -> picked points, 1 -> picked lines,
//                   result 3 -> finish() + historyManager.newBranch + cp.modified
//   long press   -> doLongTransition (mirror tool draws its temp line as the mirror line)
//   drag         -> selection rectangle + doBatchPointOperation / doBatchLineOperation
//   pinch / pan  -> ViewTransform scale/translate (handled by the paint screen)
//   undo / redo  -> historyManager.undo/redo + reset machine + refresh render data
//   overflow     -> SelectLineSM.selectAll / deselectAll / deleteSelected
//
// All ORIPACore usage of the paint fragment is confined to this file.
import Foundation
import ORIPACore

@MainActor
public final class PaintDriver: ObservableObject {
    public let session: EditorSession
    public let menu: PaintMenuModel
    public let renderer: PaintRenderer

    private let cp: CreasePattern
    private let smm: StateMachineManager
    private let context: EditorCpContext

    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false
    @Published public private(set) var toolType: Int = 0

    /// Result codes (CpTransitionResult).
    private enum TransitionResult {
        static let changedPoints = 0
        static let changedLines = 1
        static let noChange = 2
        static let finished = 3
    }

    public init(session: EditorSession, menu: PaintMenuModel, renderer: PaintRenderer) {
        self.session = session
        self.menu = menu
        self.renderer = renderer
        self.cp = session.cp
        self.smm = session.stateMachineManager
        self.context = EditorCpContext(
            prefs: session.prefs,
            byValue: PaintByValueAccessors(
                getAngleDeg: { [weak menu] in menu?.byValueAngleValue ?? 0 },
                getLength: { [weak menu] in menu?.byValueLengthValue ?? 0 },
                setAngleDeg: { [weak menu] value in menu?.setByValueAngle(value) },
                setLength: { [weak menu] value in menu?.setByValueLength(value) }))
    }

    // MARK: - Setup / tool selection

    /// `initializeTools()`: create the machine for the current action + add method.
    public func initialize() {
        rebuildMachineForCurrentAction()
        applyLineType()
        syncUndoRedo()
        syncToolType()
        refreshRenderData()
        clearPicked()
    }

    /// `setCurrentStateMachineAllActions()`.
    public func rebuildMachineForCurrentAction() {
        switch menu.currentAction.action {
        case .add:
            rebuildAddMachine()
        case .change:
            smm.newMachine(ChangeLineSM(directSelectionEnabled))
        case .select:
            smm.newMachine(SelectLineSM(directSelectionEnabled))
        case .delete:
            smm.newMachine(DeleteLineSM(directSelectionEnabled))
        case .deleteVertex:
            smm.newMachine(DeleteVertexSM(directSelectionEnabled))
        }
        syncToolType()
        renderer.requestDraw()
    }

    /// `setCurrentStateMachineAddLine(direct)`.
    private func rebuildAddMachine() {
        let method = menu.currentMethod
        if method.id == PaintTools.Id.methodByValue {
            rebuildByValueMachine()
            return
        }
        switch method.machineName {
        case "AddSegmentSM": smm.newMachine(AddSegmentSM(directSelectionEnabled))
        case "AddLineSM": smm.newMachine(AddLineSM(directSelectionEnabled))
        case "AddPerpendicularBisectorSM": smm.newMachine(AddPerpendicularBisectorSM(directSelectionEnabled))
        case "AddAngleBisectorSM": smm.newMachine(AddAngleBisectorSM(directSelectionEnabled))
        case "AddTriangleIncenterSM": smm.newMachine(AddTriangleIncenterSM(directSelectionEnabled))
        case "AddPerpendicularSegmentSM": smm.newMachine(AddPerpendicularSegmentSM(directSelectionEnabled))
        case "AddSymmetricalSegmentSM": smm.newMachine(AddSymmetricalSegmentSM(directSelectionEnabled))
        case "AddLineExtensionSM": smm.newMachine(AddLineExtensionSM(directSelectionEnabled))
        case "AddMirroredLinesSM": smm.newMachine(AddMirroredLinesSM(directSelectionEnabled))
        default: smm.newMachine(AddSegmentSM(directSelectionEnabled))
        }
    }

    /// `setCurrentStateMachineAddLineByValue(direct, index)`.
    private func rebuildByValueMachine() {
        switch menu.byValueEntry {
        case .getAngle: smm.newMachine(AddSegmentByValueGetAngleSM(directSelectionEnabled))
        case .getLength: smm.newMachine(AddSegmentByValueGetLengthSM(directSelectionEnabled))
        case .drawLine: smm.newMachine(AddSegmentByValueDrawLineSM(directSelectionEnabled))
        }
    }

    /// `applyLineType()`: `cp.inputLineType` + the renderer's picked-point colour.
    public func applyLineType() {
        let type = LineType(rawValue: menu.inputLineType) ?? .mountain
        cp.inputLineType = type
        renderer.setInputLineType(type.rawValue)
        renderer.requestDraw()
    }

    /// By-value spinner selection changed (`onByValueSpinnerItemSelected`).
    public func applyByValueEntry() {
        if currentToolType == 9 {
            rebuildByValueMachine()
            syncToolType()
        }
        clearPicked()
        renderer.requestDraw()
    }

    private var directSelectionEnabled: Bool {
        session.settings.directSelection
    }

    private func syncToolType() {
        let next = smm.getToolType()
        if next != toolType { toolType = next }
    }

    /// `smm.getToolType()` for the help dialog.
    public var currentToolType: Int { smm.getToolType() }

    // MARK: - Snapping / radii

    private func snapEnabled() -> Bool {
        if smm.hasBatchPointOperation() || smm.hasBatchLineOperation() { return false }
        return session.settings.showGrid
    }

    private func touchRadiusObject() -> Double {
        max(5.0e-4, Double(renderer.viewTransform.getObjectRadiusFromTouchPxRadius()))
    }

    private func objectPoint(x: CGFloat, y: CGFloat) -> PointDouble {
        let p = renderer.viewTransform.screenToObject(x: x, y: y)
        return PointDouble(Double(p.x), Double(p.y))
    }

    // MARK: - Transitions (tap / long press)

    public func tap(x: CGFloat, y: CGFloat) {
        let point = objectPoint(x: x, y: y)
        let radius = touchRadiusObject()
        let result = smm.doTransition(creasePattern: cp, snap: snapEnabled(),
                                      pointDouble: point, radius: radius)
        handleTransitionResult(result)
    }

    public func longPress(x: CGFloat, y: CGFloat) {
        let point = objectPoint(x: x, y: y)
        let radius = touchRadiusObject()
        let result = smm.doLongTransition(creasePattern: cp, z: session.settings.showGrid,
                                          pointDouble: point, radius: radius)
        if currentToolType == 8 && result != TransitionResult.noChange {
            if let tempLine = smm.getState().tempLinePicked {
                renderer.setMirrorLine(CoreRenderBridge.paintLine(tempLine))
            }
        }
        handleTransitionResult(result)
    }

    private func handleTransitionResult(_ result: Int) {
        switch result {
        case TransitionResult.changedPoints:
            updatePickedPoints()
        case TransitionResult.changedLines:
            updatePickedLines()
        case TransitionResult.finished:
            let historyGroup = smm.finish(context: context, cp: cp)
            _ = updateHistory(historyGroup)
            clearPicked()
            smm.resetMachine()
            syncToolType()
        default:
            return
        }
        renderer.requestDraw()
    }

    // MARK: - Batch operations (selection rectangle)

    public func isBatchOperation() -> Bool {
        smm.hasBatchPointOperation() || smm.hasBatchLineOperation()
    }

    public func batchOperation(start: CGPoint, end: CGPoint) {
        let startPoint = OriPoint(Double(start.x), Double(start.y))
        let endPoint = OriPoint(Double(end.x), Double(end.y))
        var historyGroup: HistoryGroup?
        if smm.hasBatchPointOperation() {
            historyGroup = smm.doBatchPointOperation(context: context, cp: cp,
                                                     start: startPoint, end: endPoint)
        } else if smm.hasBatchLineOperation() {
            historyGroup = smm.doBatchLineOperation(context: context, cp: cp,
                                                    start: startPoint, end: endPoint)
            if let group = historyGroup, group.isEmpty() {
                updatePickedLines()
            }
        }
        if updateHistory(historyGroup) {
            clearPicked()
            smm.resetMachine()
            syncToolType()
        }
        renderer.requestDraw()
    }

    // MARK: - History

    @discardableResult
    private func updateHistory(_ historyGroup: HistoryGroup?) -> Bool {
        guard let historyGroup, !historyGroup.isEmpty() else { return false }
        cp.historyManager.newBranch(historyGroup)
        session.contentChanged()
        syncUndoRedo()
        refreshRenderData()
        return true
    }

    public func undo() {
        guard session.undo() else { return }
        smm.resetMachine()
        syncToolType()
        clearPicked()
        syncUndoRedo()
        refreshRenderData()
    }

    public func redo() {
        guard session.redo() else { return }
        smm.resetMachine()
        syncToolType()
        clearPicked()
        syncUndoRedo()
        refreshRenderData()
    }

    public func syncUndoRedo() {
        let canUndoNow = cp.historyManager.hasUndo()
        let canRedoNow = cp.historyManager.hasRedo()
        if canUndoNow != canUndo { canUndo = canUndoNow }
        if canRedoNow != canRedo { canRedo = canRedoNow }
        session.refreshUndoRedo()
    }

    // MARK: - Render data

    public func refreshRenderData() {
        CoreRenderBridge.refreshPaint(renderer, cp: cp)
    }

    // MARK: - Picked data (CpState)

    public func clearPicked() {
        renderer.setPickedPoints([])
        renderer.setPickedMVFBPoints([])
        renderer.setPickedLines([])
        renderer.setMirrorLine(nil)
        renderer.requestDraw()
    }

    public func updatePickedPoints() {
        let state = smm.getState()
        let picked = CoreRenderBridge.paintPoints(state.pointsPicked.values())
        renderer.setPickedMVFBPoints(picked)
        if let temp = state.tempPointPicked {
            renderer.setPickedPoints([PaintPoint(x: CGFloat(temp.x), y: CGFloat(temp.y))])
        } else {
            renderer.setPickedPoints([])
        }
    }

    public func updatePickedLines() {
        let state = smm.getState()
        renderer.setPickedLines(CoreRenderBridge.paintLines(state.linesPicked.values()))
    }

    // MARK: - Overflow actions (Select Line tool)

    public func selectAllLines() {
        if let machine = smm.getCurrentMachine() as? SelectLineSM {
            machine.selectAll(cp)
            updatePickedLines()
            renderer.requestDraw()
        }
    }

    public func deselectAllLines() {
        if let machine = smm.getCurrentMachine() as? SelectLineSM {
            machine.deselectAll()
            updatePickedLines()
            renderer.requestDraw()
        }
    }

    public func deleteSelectedLines() {
        guard let machine = smm.getCurrentMachine() as? SelectLineSM else { return }
        let historyGroup = machine.deleteSelected(cp)
        if updateHistory(historyGroup) {
            clearPicked()
            smm.resetMachine()
            syncToolType()
        }
        renderer.requestDraw()
    }

    /// "Clear Selection" overflow item (`smm.resetMachine(); clearPicked()`).
    public func clearSelectionAction() {
        smm.resetMachine()
        syncToolType()
        clearPicked()
        renderer.requestDraw()
    }
}
