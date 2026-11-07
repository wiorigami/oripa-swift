// Port of `com.origamitoolbox.oripa.model.tool.SelectLineSM`
// (oripa-port src/js/core/model/tool/SelectLineSM.js).
//
// "Select Line": toggles lines with taps (and adds drag-rectangle selections to the picked set);
// the overflow menu drives `selectAll` / `deselectAll` / `deleteSelected`.
import Foundation

public final class SelectLineSM: LinesToggleStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.SELECT_LINE.rawValue,
            directSelectionEnabled: directSelectionEnabled
        )
    }

    public func deleteSelected(_ creasePattern: CreasePattern) -> HistoryGroup {
        let set = getState().linesPicked
        let historyGroup = HistoryGroup(getToolType())
        if set.isEmpty() {
            return historyGroup
        }
        let hashSet = JavaSet<OriPoint>()
        let iterator = set.iterator()
        while iterator.hasNext() {
            let oriLine = iterator.next()
            creasePattern.removeLine(oriLine)
            let historyItem = HistoryItem()
            historyItem.oldLines.append(oriLine)
            historyGroup.add(historyItem)
            hashSet.add(oriLine.start)
            hashSet.add(oriLine.end)
        }
        historyGroup.addAll(creasePattern.cleanStraightLines(hashSet))
        return historyGroup
    }

    public func deselectAll() {
        getState().linesPicked.clear()
    }

    public override func doBatchLineOperationSet(
        _ context: CpContext?,
        _ creasePattern: CreasePattern,
        _ set: JavaSet<OriLine>
    ) -> HistoryGroup {
        getState().linesPicked.addAll(set.values())
        return HistoryGroup(getToolType())
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        HistoryGroup(getToolType())
    }

    public override func getNew() -> CpStateMachine {
        SelectLineSM(getDirectSelectionEnabled())
    }

    public override func hasBatchLineOperation() -> Bool { true }

    public func selectAll(_ creasePattern: CreasePattern) {
        getState().linesPicked.addAll(creasePattern.lineMVFB.getAllLines())
    }
}
