// Port of `com.origamitoolbox.oripa.model.tool.AddMirroredLinesSM`
// (oripa-port src/js/core/model/tool/AddMirroredLinesSM.js).
//
// "Mirror": toggles any number of lines with taps/drag rectangles, then a long-press picks the
// mirror axis (`tempLinePicked`); `finish` adds the mirrored copies of every picked line.
import Foundation

public final class AddMirroredLinesSM: LinesToggleStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_MIRRORED_LINES.rawValue,
            directSelectionEnabled: directSelectionEnabled
        )
    }

    public override func doBatchLineOperationSet(
        _ context: CpContext?,
        _ creasePattern: CreasePattern,
        _ set: JavaSet<OriLine>
    ) -> HistoryGroup {
        getState().linesPicked.addAll(set.values())
        return HistoryGroup(getToolType())
    }

    public override func doLongTransition(
        creasePattern: CreasePattern,
        z: Bool,
        pointDouble: PointDouble,
        radius: Double
    ) -> Int {
        guard let oriLine = creasePattern.findLine(z, pointDouble, radius) else {
            return CpTransitionResult.NO_CHANGE.rawValue
        }
        getState().tempLinePicked = oriLine
        return CpTransitionResult.FINISHED.rawValue
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let state = getState()
        let historyGroup = HistoryGroup(getToolType())
        // The JS reference dereferences `tempLinePicked` unconditionally (the long-press flow
        // always sets it before FINISHED); stay nil-safe like the other optional adaptations.
        guard let oriLine = state.tempLinePicked else { return historyGroup }
        let mirrorTransformMatrix = GeomUtil.getMirrorTransformMatrix(oriLine.start, oriLine.end)
        for oriLine2 in state.linesPicked.values() {
            let transformedLine = GeomUtil.getTransformedLine(
                oriLine2.start, oriLine2.end, mirrorTransformMatrix
            )
            historyGroup.add(addNewLine(
                cp, transformedLine.start, transformedLine.end, oriLine2.type()
            ))
        }
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        AddMirroredLinesSM(getDirectSelectionEnabled())
    }

    public override func hasBatchLineOperation() -> Bool { true }
}
