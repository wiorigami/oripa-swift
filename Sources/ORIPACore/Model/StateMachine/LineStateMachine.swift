// Port of `com.origamitoolbox.oripa.model.statemachine.LineStateMachine`
// (oripa-port src/js/core/model/statemachine/LineStateMachine.js).
//
// Abstract base for machines that pick exactly one line (ChangeLineSM / DeleteLineSM).
// `currentEvent` follows `CpEvent`: SET_TEMP_LINE(2) -> CONFIRM_LINE(3) in indirect mode,
// FINISH(4) once the line is confirmed.
import Foundation

open class LineStateMachine: CpStateMachine {
    private var currentEvent: Int

    override init(toolType: Int, directSelectionEnabled: Bool) {
        self.currentEvent = directSelectionEnabled ? CpEvent.confirmLine.rawValue
                                                   : CpEvent.setTempLine.rawValue
        super.init(toolType: toolType, directSelectionEnabled: directSelectionEnabled)
    }

    open override func doDirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
        guard let oriLine = creasePattern.findLine(z, pointDouble, d) else {
            return CpTransitionResult.NO_CHANGE.rawValue
        }
        state.linesPicked.add(oriLine)
        currentEvent = CpEvent.finish.rawValue
        return CpTransitionResult.FINISHED.rawValue
    }

    open override func doIndirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
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
            return CpTransitionResult.NO_CHANGE.rawValue
        }
    }
}
