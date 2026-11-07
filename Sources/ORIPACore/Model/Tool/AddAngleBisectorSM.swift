// Port of `com.origamitoolbox.model.tool.AddAngleBisectorSM`
// (oripa-port src/js/core/model/tool/AddAngleBisectorSM.js).
//
// "Angle Bisector": picks three points (p0, apex p1, p2) and one line; draws the angle bisector
// at p1 up to its intersection with the picked line.
import Foundation

public final class AddAngleBisectorSM: PointsAndLineStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_ANGLE_BISECTOR.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 3
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let state = getState()
        let pointDoubleArr = state.pointsPicked.toArray()
        let oriLine = state.linesPicked.toArray()[0]
        let angleRadians = (GeomUtil.getAngleRadians(pointDoubleArr[1], pointDoubleArr[2])
            + GeomUtil.getAngleRadians(pointDoubleArr[1], pointDoubleArr[0])) / 2.0
        let lineIntersect = GeomUtil.getLineIntersect(
            pointDoubleArr[1],
            PointDouble(
                pointDoubleArr[1].x + cos(angleRadians),
                pointDoubleArr[1].y + sin(angleRadians)
            ),
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
        AddAngleBisectorSM(getDirectSelectionEnabled())
    }
}
