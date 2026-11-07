// Port of `com.origamitoolbox.oripa.model.tool.AddTriangleIncenterSM`
// (oripa-port src/js/core/model/tool/AddTriangleIncenterSM.js).
//
// "Add Triangle Incenter": picks three points and draws the three segments from each point to
// the triangle's incenter.
import Foundation

public final class AddTriangleIncenterSM: PointsStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_TRIANGLE_INCENTER.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 3
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let pointDoubleArr = getState().pointsPicked.toArray()
        let incenter = GeomUtil.getIncenter(pointDoubleArr[0], pointDoubleArr[1], pointDoubleArr[2])
        let historyGroup = HistoryGroup(getToolType())
        for pointDouble in pointDoubleArr {
            historyGroup.add(addNewLine(cp, pointDouble, incenter))
        }
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        AddTriangleIncenterSM(getDirectSelectionEnabled())
    }
}
