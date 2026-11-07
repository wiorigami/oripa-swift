// Port of `com.origamitoolbox.oripa.model.statemachine.LinesToggleStateMachine`
// (oripa-port src/js/core/model/statemachine/LinesToggleStateMachine.js).
//
// Abstract base for machines that toggle any number of lines (SelectLineSM / AddMirroredLinesSM):
// direct and indirect selection behave identically (each tap toggles the line under the finger).
import Foundation

open class LinesToggleStateMachine: CpStateMachine {
    override init(toolType: Int, directSelectionEnabled: Bool) {
        super.init(toolType: toolType, directSelectionEnabled: directSelectionEnabled)
    }

    open override func doDirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
        doIndirectTransition(creasePattern, z, pointDouble, d)
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
        if state.linesPicked.contains(oriLine) {
            state.linesPicked.remove(oriLine)
            return CpTransitionResult.CHANGED_LINES.rawValue
        }
        state.linesPicked.add(oriLine)
        return CpTransitionResult.CHANGED_LINES.rawValue
    }
}
