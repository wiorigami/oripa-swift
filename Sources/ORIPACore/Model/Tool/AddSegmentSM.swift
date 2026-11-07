// Port of `com.origamitoolbox.oripa.model.tool.AddSegmentSM`
// (oripa-port src/js/core/model/tool/AddSegmentSM.js).
//
// "Add Segment": picks two existing points, then `finish` inserts the line between them.
import Foundation

public final class AddSegmentSM: PointsStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_SEGMENT.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 2
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let pointDoubleArr = getState().pointsPicked.toArray()
        let historyItem = addNewLine(cp, pointDoubleArr[0], pointDoubleArr[1])
        let historyGroup = HistoryGroup(getToolType())
        historyGroup.add(historyItem)
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        AddSegmentSM(getDirectSelectionEnabled())
    }
}
