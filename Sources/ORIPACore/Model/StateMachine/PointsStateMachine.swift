// Port of `com.origamitoolbox.oripa.model.statemachine.PointsStateMachine`
// (oripa-port src/js/core/model/statemachine/PointsStateMachine.js).
//
// Abstract base for machines that only pick points (AddSegmentSM, AddTriangleIncenterSM,
// AddSegmentByValue*SM, DeleteVertexSM). Indirect mode asks for every point twice: the first
// tap sets `tempPointPicked`, the second confirms it.
import Foundation

open class PointsStateMachine: CpStateMachine {
    private var currentEvent: Int
    private let pointAcceptedCount: Int

    init(toolType: Int, directSelectionEnabled: Bool, pointAcceptedCount: Int) {
        self.currentEvent = directSelectionEnabled ? CpEvent.confirmPoint.rawValue
                                                   : CpEvent.setTempPoint.rawValue
        self.pointAcceptedCount = pointAcceptedCount
        super.init(toolType: toolType, directSelectionEnabled: directSelectionEnabled)
    }

    open override func doDirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
        guard let oriPoint = creasePattern.findPoint(z, pointDouble, d),
              !state.pointsPicked.contains(oriPoint) else {
            return CpTransitionResult.NO_CHANGE.rawValue
        }
        state.pointsPicked.add(oriPoint)
        if state.pointsPicked.size() < pointAcceptedCount {
            return CpTransitionResult.CHANGED_POINTS.rawValue
        }
        currentEvent = CpEvent.finish.rawValue
        return CpTransitionResult.FINISHED.rawValue
    }

    open override func doIndirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
        guard let oriPoint = creasePattern.findPoint(z, pointDouble, d) else {
            return CpTransitionResult.NO_CHANGE.rawValue
        }
        switch currentEvent {
        case CpEvent.setTempPoint.rawValue:
            if !state.pointsPicked.contains(oriPoint) {
                state.tempPointPicked = oriPoint
                currentEvent = CpEvent.confirmPoint.rawValue
                return CpTransitionResult.CHANGED_POINTS.rawValue
            }
            return CpTransitionResult.NO_CHANGE.rawValue
        case CpEvent.confirmPoint.rawValue:
            if !state.tempPointPicked!.equals(oriPoint) {
                if !state.pointsPicked.contains(oriPoint) {
                    state.tempPointPicked = oriPoint
                    currentEvent = CpEvent.confirmPoint.rawValue
                    return CpTransitionResult.CHANGED_POINTS.rawValue
                }
                return CpTransitionResult.NO_CHANGE.rawValue
            }
            state.pointsPicked.add(oriPoint)
            state.tempPointPicked = nil
            if state.pointsPicked.size() < pointAcceptedCount {
                currentEvent = CpEvent.setTempPoint.rawValue
                return CpTransitionResult.CHANGED_POINTS.rawValue
            }
            currentEvent = CpEvent.finish.rawValue
            return CpTransitionResult.FINISHED.rawValue
        default:
            return CpTransitionResult.NO_CHANGE.rawValue
        }
    }
}
