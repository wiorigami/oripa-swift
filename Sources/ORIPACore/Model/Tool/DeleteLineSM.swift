// Port of `com.origamitoolbox.oripa.model.tool.DeleteLineSM`
// (oripa-port src/js/core/model/tool/DeleteLineSM.js).
//
// "Delete Line": picks one line (or a drag rectangle) and removes it — filtered by the
// `PaintCpFragment.deleteLineType` preference — then merges any collinear leftovers.
import Foundation

/// `SharedPreferences.getInt(key, default)` equivalent for the JS port's optional context.
private func getPrefInt(_ context: CpContext?, _ key: String, _ defaultValue: Int) -> Int {
    context?.getPref(key, defaultValue) ?? defaultValue
}

public final class DeleteLineSM: LineStateMachine {
    /// `R.id.*` values used as preference values (exact numbers from the decompiled `R.java`).
    public enum RID {
        public static let ANY = 0x7F09_00B4
        public static let BOUNDARY = 0x7F09_00B5
        public static let FLAT = 0x7F09_00B6
        public static let MOUNTAIN = 0x7F09_00B7
        public static let VALLEY = 0x7F09_00B8
    }

    public static let PREF_KEY_PAINT_DELETE_LINE_TYPE = "PaintCpFragment.deleteLineType"

    private var prefTypeMap: [Int: LineType] = [:]

    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.DELETE_LINE.rawValue,
            directSelectionEnabled: directSelectionEnabled
        )
        prefTypeMap[RID.MOUNTAIN] = .mountain
        prefTypeMap[RID.VALLEY] = .valley
        prefTypeMap[RID.FLAT] = .flat
        prefTypeMap[RID.BOUNDARY] = .boundary
    }

    public override func doBatchLineOperationSet(
        _ context: CpContext?,
        _ creasePattern: CreasePattern,
        _ set: JavaSet<OriLine>
    ) -> HistoryGroup {
        let historyGroup = HistoryGroup(getToolType())
        if set.isEmpty() {
            return historyGroup
        }
        let i = getPrefInt(
            context, DeleteLineSM.PREF_KEY_PAINT_DELETE_LINE_TYPE, DeleteLineSM.RID.ANY
        )
        let hashSet = JavaSet<OriPoint>()
        let iterator = set.iterator()
        while iterator.hasNext() {
            let oriLine = iterator.next()
            let bType = oriLine.type()
            if i == RID.ANY || bType == prefTypeMap[i] {
                creasePattern.removeLine(oriLine)
                let historyItem = HistoryItem()
                historyItem.oldLines.append(oriLine)
                historyGroup.add(historyItem)
                hashSet.add(oriLine.start)
                hashSet.add(oriLine.end)
            }
        }
        historyGroup.addAll(creasePattern.cleanStraightLines(hashSet))
        return historyGroup
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let oriLine = getState().linesPicked.toArray()[0]
        let i = getPrefInt(
            context, DeleteLineSM.PREF_KEY_PAINT_DELETE_LINE_TYPE, DeleteLineSM.RID.ANY
        )
        let bType = oriLine.type()
        let historyGroup = HistoryGroup(getToolType())
        if i != RID.ANY && bType != prefTypeMap[i] {
            return historyGroup
        }
        cp.removeLine(oriLine)
        let historyItem = HistoryItem()
        historyItem.oldLines.append(oriLine)
        historyGroup.add(historyItem)
        let hashSet = JavaSet<OriPoint>()
        hashSet.add(oriLine.start)
        hashSet.add(oriLine.end)
        historyGroup.addAll(cp.cleanStraightLines(hashSet))
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        DeleteLineSM(getDirectSelectionEnabled())
    }

    public override func hasBatchLineOperation() -> Bool { true }
}
