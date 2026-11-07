// Port of `com.origamitoolbox.oripa.model.tool.DeleteVertexSM`
// (oripa-port src/js/core/model/tool/DeleteVertexSM.js).
//
// "Clean Vertex": picks one vertex (or a rectangle via the batch point operation) and merges
// collinear line pairs through it (`CreasePattern.cleanStraightLines`).
import Foundation

public final class DeleteVertexSM: PointsStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.DELETE_VERTEX.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 1
        )
    }

    public override func doBatchPointOperationSet(
        _ context: CpContext?,
        _ creasePattern: CreasePattern,
        _ set: JavaSet<OriPoint>
    ) -> HistoryGroup {
        let historyGroup = HistoryGroup(getToolType())
        if set.isEmpty() {
            return historyGroup
        }
        historyGroup.addAll(creasePattern.cleanStraightLines(set))
        return historyGroup
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let oriPoint = getState().pointsPicked.toArray()[0]
        let hashSet = JavaSet<OriPoint>()
        hashSet.add(oriPoint)
        let list = cp.cleanStraightLines(hashSet)
        let historyGroup = HistoryGroup(getToolType())
        historyGroup.addAll(list)
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        DeleteVertexSM(getDirectSelectionEnabled())
    }

    public override func hasBatchPointOperation() -> Bool { true }
}
