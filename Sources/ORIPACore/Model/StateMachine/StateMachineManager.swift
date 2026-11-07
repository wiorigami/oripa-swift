// Port of `com.origamitoolbox.oripa.model.statemachine.StateMachineManager`
// (oripa-port src/js/core/model/statemachine/StateMachineManager.js).
//
// Holds the tool's current state machine and delegates every transition/finish/batch call to
// it. Boundary API from docs/PORT-CONTRACT.md §5.1: the editor creates one manager and swaps
// machines with `newMachine(_:)` when the user changes tool.
import Foundation

public final class StateMachineManager: BasicCpStateMachine {
    /// Java `private CpStateMachine currentStateMachine = null`.
    public private(set) var currentStateMachine: CpStateMachine?

    public init() {}

    // MARK: - Delegation

    public func doBatchLineOperation(
        context: CpContext?,
        cp: CreasePattern,
        start: OriPoint,
        end: OriPoint
    ) -> HistoryGroup {
        guard let currentStateMachine else { return HistoryGroup(0) }
        return currentStateMachine.doBatchLineOperation(context: context, cp: cp, start: start, end: end)
    }

    public func doBatchPointOperation(
        context: CpContext?,
        cp: CreasePattern,
        start: OriPoint,
        end: OriPoint
    ) -> HistoryGroup {
        guard let currentStateMachine else { return HistoryGroup(0) }
        return currentStateMachine.doBatchPointOperation(context: context, cp: cp, start: start, end: end)
    }

    public func doLongTransition(
        creasePattern: CreasePattern,
        z: Bool,
        pointDouble: PointDouble,
        radius: Double
    ) -> Int {
        guard let currentStateMachine else { return CpTransitionResult.NO_CHANGE.rawValue }
        return currentStateMachine.doLongTransition(
            creasePattern: creasePattern, z: z, pointDouble: pointDouble, radius: radius
        )
    }

    public func doTransition(
        creasePattern: CreasePattern,
        snap: Bool,
        pointDouble: PointDouble,
        radius: Double
    ) -> Int {
        guard let currentStateMachine else { return CpTransitionResult.NO_CHANGE.rawValue }
        return currentStateMachine.doTransition(
            creasePattern: creasePattern, snap: snap, pointDouble: pointDouble, radius: radius
        )
    }

    public func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        guard let currentStateMachine else { return HistoryGroup(0) }
        return currentStateMachine.finish(context: context, cp: cp)
    }

    public func getCurrentMachine() -> CpStateMachine? { currentStateMachine }

    public func getDirectSelectionEnabled() -> Bool {
        currentStateMachine?.getDirectSelectionEnabled() ?? false
    }

    public func getState() -> CpState {
        // JS dereferences the current machine unconditionally; the optional-safe fallback keeps
        // the native port from crashing before the first `newMachine` call.
        currentStateMachine?.getState() ?? CpState()
    }

    /// Tool type of the current machine; `-1` when no machine has been created yet (the JS
    /// reference would throw on a null dereference; the editor checks for `-1` instead).
    public func getToolType() -> Int {
        currentStateMachine?.getToolType() ?? -1
    }

    public func hasBatchLineOperation() -> Bool {
        currentStateMachine?.hasBatchLineOperation() ?? false
    }

    public func hasBatchPointOperation() -> Bool {
        currentStateMachine?.hasBatchPointOperation() ?? false
    }

    public func newMachine(_ cpStateMachine: CpStateMachine) {
        currentStateMachine = cpStateMachine
    }

    public func resetMachine() {
        currentStateMachine = currentStateMachine?.getNew()
    }
}
