// Port of `com.origamitoolbox.oripa.model.statemachine.PointsAndLineStateMachine`
// (oripa-port src/js/core/model/statemachine/PointsAndLineStateMachine.js).
//
// Abstract base for machines that pick N points first and then exactly one line
// (AddPerpendicularSegmentSM, AddAngleBisectorSM, AddLineExtensionSM, AddSymmetricalSegmentSM).
import Foundation

open class PointsAndLineStateMachine: CpStateMachine {
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
        if state.pointsPicked.size() >= pointAcceptedCount {
            guard let oriLine = creasePattern.findLine(z, pointDouble, d) else {
                return CpTransitionResult.NO_CHANGE.rawValue
            }
            state.linesPicked.add(oriLine)
            currentEvent = CpEvent.finish.rawValue
            return CpTransitionResult.FINISHED.rawValue
        }
        guard let oriPoint = creasePattern.findPoint(z, pointDouble, d),
              !state.pointsPicked.contains(oriPoint) else {
            return CpTransitionResult.NO_CHANGE.rawValue
        }
        state.pointsPicked.add(oriPoint)
        if state.pointsPicked.size() != pointAcceptedCount {
            return CpTransitionResult.CHANGED_POINTS.rawValue
        }
        currentEvent = CpEvent.confirmLine.rawValue
        return CpTransitionResult.CHANGED_POINTS.rawValue
    }

    open override func doIndirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
        if state.pointsPicked.size() >= pointAcceptedCount {
            guard let oriLine = creasePattern.findLine(z, pointDouble, d) else {
                return CpTransitionResult.NO_CHANGE.rawValue
            }
            switch currentEvent {
            case CpEvent.setTempLine.rawValue:
                state.linesPicked.add(oriLine)
                currentEvent = CpEvent.confirmLine.rawValue
                return CpTransitionResult.CHANGED_LINES.rawValue
            case CpEvent.confirmLine.rawValue:
                if state.linesPicked.contains(oriLine) {
                    currentEvent = CpEvent.finish.rawValue
                    return CpTransitionResult.FINISHED.rawValue
                }
                state.linesPicked.clear()
                state.linesPicked.add(oriLine)
                currentEvent = CpEvent.confirmLine.rawValue
                return CpTransitionResult.CHANGED_LINES.rawValue
            default:
                break
            }
        }
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
        case CpEvent.confirmPoint.rawValue:
            if state.tempPointPicked!.equals(oriPoint) {
                state.pointsPicked.add(oriPoint)
                state.tempPointPicked = nil
                if state.pointsPicked.size() < pointAcceptedCount {
                    currentEvent = CpEvent.setTempPoint.rawValue
                } else {
                    currentEvent = CpEvent.setTempLine.rawValue
                }
                return CpTransitionResult.CHANGED_POINTS.rawValue
            }
            if !state.pointsPicked.contains(oriPoint) {
                state.tempPointPicked = oriPoint
                currentEvent = CpEvent.confirmPoint.rawValue
                return CpTransitionResult.CHANGED_POINTS.rawValue
            }
        default:
            break
        }
        return CpTransitionResult.NO_CHANGE.rawValue
    }
}
