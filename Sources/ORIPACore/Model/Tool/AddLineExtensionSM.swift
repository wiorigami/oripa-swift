// Port of `com.origamitoolbox.oripa.model.tool.AddLineExtensionSM`
// (oripa-port src/js/core/model/tool/AddLineExtensionSM.js).
//
// "Extend Line": picks two points and one line; extends the point-to-point segment to the line
// when the line lies beyond the second point (otherwise the reference rejects the edit).
import Foundation

public final class AddLineExtensionSM: PointsAndLineStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_LINE_EXTENSION.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 2
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let state = getState()
        let pointDoubleArr = state.pointsPicked.toArray()
        let oriLine = state.linesPicked.toArray()[0]
        let historyGroup = HistoryGroup(getToolType())
        guard let lineIntersect = GeomUtil.getLineIntersect(
            pointDoubleArr[0], pointDoubleArr[1], oriLine.start, oriLine.end
        ) else {
            return historyGroup
        }
        if GeomUtil.getDistance(pointDoubleArr[0], lineIntersect)
                < GeomUtil.getDistance(pointDoubleArr[1], lineIntersect)
            || GeomUtil.getDistance(pointDoubleArr[0], pointDoubleArr[1])
                > GeomUtil.getDistance(pointDoubleArr[0], lineIntersect)
        {
            return HistoryGroup(getToolType())
        }
        historyGroup.add(addNewLine(cp, pointDoubleArr[1], lineIntersect))
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        AddLineExtensionSM(getDirectSelectionEnabled())
    }
}
