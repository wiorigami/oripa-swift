// Port of `com.origamitoolbox.oripa.model.tool.AddPerpendicularSegmentSM`
// (oripa-port src/js/core/model/tool/AddPerpendicularSegmentSM.js).
//
// "Perpendicular Segment": picks one point and one line; draws the perpendicular from the point
// to the line.
import Foundation

public final class AddPerpendicularSegmentSM: PointsAndLineStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_PERPENDICULAR_SEGMENT.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 1
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let state = getState()
        let pointDouble = state.pointsPicked.toArray()[0]
        let oriLine = state.linesPicked.toArray()[0]
        let historyItem = addNewLine(
            cp,
            pointDouble,
            GeomUtil.getPerpendicularIntersect(oriLine.start, oriLine.end, pointDouble)
        )
        let historyGroup = HistoryGroup(getToolType())
        historyGroup.add(historyItem)
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        AddPerpendicularSegmentSM(getDirectSelectionEnabled())
    }
}
