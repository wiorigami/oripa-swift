// Port of `com.origamitoolbox.oripa.model.tool.AddSegmentByValueGetLengthSM`
// (oripa-port src/js/core/model/tool/AddSegmentByValueGetLengthSM.js).
//
// "Segment by Value — get length": picks two points and writes their distance into the paint
// fragment's length field.
import Foundation

public final class AddSegmentByValueGetLengthSM: PointsStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_SEGMENT_BY_VALUE.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 2
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let pointDoubleArr = getState().pointsPicked.toArray()
        if let context {
            context.setByValueButtonLengthText(
                GeomUtil.getDistance(pointDoubleArr[0], pointDoubleArr[1])
            )
        }
        return HistoryGroup(getToolType())
    }

    public override func getNew() -> CpStateMachine {
        AddSegmentByValueGetLengthSM(getDirectSelectionEnabled())
    }
}
