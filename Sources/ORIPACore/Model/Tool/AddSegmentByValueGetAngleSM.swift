// Port of `com.origamitoolbox.oripa.model.tool.AddSegmentByValueGetAngleSM`
// (oripa-port src/js/core/model/tool/AddSegmentByValueGetAngleSM.js).
//
// "Segment by Value — get angle": picks two points and writes the (negated) segment angle in
// degrees into the paint fragment's angle field. Android casts the context to PaintCpFragment;
// the port reads the shared `CpContext` protocol (`context.paintFragment` in the JS port).
import Foundation

public final class AddSegmentByValueGetAngleSM: PointsStateMachine {
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
            let degrees = GeomUtil.getAngleRadians(pointDoubleArr[0], pointDoubleArr[1])
                * 180.0 / Double.pi
            context.setByValueButtonAngleDegText(degrees * (-1.0))
        }
        return HistoryGroup(getToolType())
    }

    public override func getNew() -> CpStateMachine {
        AddSegmentByValueGetAngleSM(getDirectSelectionEnabled())
    }
}
