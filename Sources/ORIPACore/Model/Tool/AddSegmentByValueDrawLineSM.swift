// Port of `com.origamitoolbox.oripa.model.tool.AddSegmentByValueDrawLineSM`
// (oripa-port src/js/core/model/tool/AddSegmentByValueDrawLineSM.js).
//
// "Segment by Value — draw line": picks one point, then draws a segment of the length/angle
// held by the paint fragment (the angle is negated: the UI edits a Y-down angle).
import Foundation

public final class AddSegmentByValueDrawLineSM: PointsStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_SEGMENT_BY_VALUE.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 1
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let pointDouble = getState().pointsPicked.toArray()[0]
        let angleDegText = context?.getByValueButtonAngleDegText() ?? 0.0
        let lengthText = context?.getByValueButtonLengthText() ?? 0.0
        let radians = (angleDegText * (-1.0)) * Double.pi / 180.0
        let historyItem = addNewLine(cp, pointDouble, PointDouble(
            pointDouble.x + (cos(radians) * lengthText),
            pointDouble.y + (lengthText * sin(radians))
        ))
        let historyGroup = HistoryGroup(getToolType())
        historyGroup.add(historyItem)
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        AddSegmentByValueDrawLineSM(getDirectSelectionEnabled())
    }
}
