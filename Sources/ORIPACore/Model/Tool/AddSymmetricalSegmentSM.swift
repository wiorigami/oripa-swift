// Port of `com.origamitoolbox.oripa.model.tool.AddSymmetricalSegmentSM`
// (oripa-port src/js/core/model/tool/AddSymmetricalSegmentSM.js).
//
// "Symmetrical Segment": picks three points (segment p0-p1, symmetry axis p1-p2) and one line;
// mirrors p0 across the p1-p2 axis and draws p1 to the intersection with the picked line.
import Foundation

public final class AddSymmetricalSegmentSM: PointsAndLineStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_SYMMETRICAL_SEGMENT.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 3
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let state = getState()
        let pointDoubleArr = state.pointsPicked.toArray()
        let oriLine = state.linesPicked.toArray()[0]
        let transformedLine = GeomUtil.getTransformedLine(
            pointDoubleArr[0],
            pointDoubleArr[1],
            GeomUtil.getMirrorTransformMatrix(pointDoubleArr[1], pointDoubleArr[2])
        )
        let lineIntersect = GeomUtil.getLineIntersect(
            transformedLine.start,
            transformedLine.end,
            oriLine.start,
            oriLine.end
        )
        let historyGroup = HistoryGroup(getToolType())
        if let lineIntersect {
            historyGroup.add(addNewLine(cp, pointDoubleArr[1], lineIntersect))
        }
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        AddSymmetricalSegmentSM(getDirectSelectionEnabled())
    }
}
