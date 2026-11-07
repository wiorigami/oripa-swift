// Port of `com.origamitoolbox.oripa.model.statemachine.PointsAndLinesStateMachine`
// (oripa-port src/js/core/model/statemachine/PointsAndLinesStateMachine.js).
//
// Abstract base for machines that pick N points and then N lines (AddLineSM,
// AddPerpendicularBisectorSM). In indirect mode the same object must be tapped twice
// (point set -> confirm; line add -> confirm).
import Foundation

open class PointsAndLinesStateMachine: CpStateMachine {
    private var currentEvent: Int
    private let pointAcceptedCount: Int
    private let lineAcceptedCount: Int

    init(
        toolType: Int,
        directSelectionEnabled: Bool,
        pointAcceptedCount: Int,
        lineAcceptedCount: Int
    ) {
        self.currentEvent = directSelectionEnabled ? CpEvent.confirmPoint.rawValue
                                                   : CpEvent.setTempPoint.rawValue
        self.pointAcceptedCount = pointAcceptedCount
        self.lineAcceptedCount = lineAcceptedCount
        super.init(toolType: toolType, directSelectionEnabled: directSelectionEnabled)
    }

    open override func doDirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
        if state.pointsPicked.size() < pointAcceptedCount {
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
        guard let oriLine = creasePattern.findLine(z, pointDouble, d),
              !state.linesPicked.contains(oriLine) else {
            return CpTransitionResult.NO_CHANGE.rawValue
        }
        state.linesPicked.add(oriLine)
        if state.linesPicked.size() != lineAcceptedCount {
            return CpTransitionResult.CHANGED_LINES.rawValue
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
        if state.pointsPicked.size() >= pointAcceptedCount {
            guard let oriLine = creasePattern.findLine(z, pointDouble, d) else {
                return CpTransitionResult.NO_CHANGE.rawValue
            }
            if state.linesPicked.contains(oriLine) {
                state.linesPicked.remove(oriLine)
            } else {
                state.linesPicked.add(oriLine)
                if state.linesPicked.size() == lineAcceptedCount {
                    currentEvent = CpEvent.finish.rawValue
                    return CpTransitionResult.FINISHED.rawValue
                }
            }
            return CpTransitionResult.CHANGED_LINES.rawValue
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
            } else {
                currentEvent = CpEvent.setTempLine.rawValue
            }
            return CpTransitionResult.CHANGED_POINTS.rawValue
        default:
            return CpTransitionResult.NO_CHANGE.rawValue
        }
    }
}
