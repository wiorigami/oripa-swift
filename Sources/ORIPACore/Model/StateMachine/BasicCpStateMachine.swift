// Port of `com.origamitoolbox.oripa.model.statemachine.BasicCpStateMachine`
// (oripa-port src/js/core/model/statemachine/BasicCpStateMachine.js — a Java interface).
//
// Implemented by `CpStateMachine` and `StateMachineManager`. Boundary API from
// docs/PORT-CONTRACT.md §5.1: the UI only ever needs these methods.
import Foundation

public protocol BasicCpStateMachine: AnyObject {
    /// Java `doBatchLineOperation(Context, CreasePattern, OriPoint, OriPoint)`.
    func doBatchLineOperation(
        context: CpContext?,
        cp: CreasePattern,
        start: OriPoint,
        end: OriPoint
    ) -> HistoryGroup

    /// Java `doBatchPointOperation(Context, CreasePattern, OriPoint, OriPoint)`.
    func doBatchPointOperation(
        context: CpContext?,
        cp: CreasePattern,
        start: OriPoint,
        end: OriPoint
    ) -> HistoryGroup

    /// Java `doLongTransition(CreasePattern, boolean, PointDouble, double)` -> `byte`.
    func doLongTransition(
        creasePattern: CreasePattern,
        z: Bool,
        pointDouble: PointDouble,
        radius: Double
    ) -> Int

    /// Java `doTransition(CreasePattern, boolean, PointDouble, double)` -> `byte`.
    func doTransition(
        creasePattern: CreasePattern,
        snap: Bool,
        pointDouble: PointDouble,
        radius: Double
    ) -> Int

    /// Java `finish(Context, CreasePattern)`.
    func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup

    func getDirectSelectionEnabled() -> Bool
    func getState() -> CpState
    func getToolType() -> Int
    func hasBatchLineOperation() -> Bool
    func hasBatchPointOperation() -> Bool
}
