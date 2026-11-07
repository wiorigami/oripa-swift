// Port of `com.origamitoolbox.oripa.model.tool.ChangeLineSM`
// (oripa-port src/js/core/model/tool/ChangeLineSM.js).
//
// "Change Line Type": picks one line (or a drag rectangle) and changes its type according to
// the Android preferences `PaintCpFragment.changeLineTypeFrom` / `...To`. The menu ids are the
// exact numeric `R.id` values from the reference APK.
import Foundation

/// `SharedPreferences.getInt(key, default)` equivalent for the JS port's optional context:
/// a missing context yields the Android default (the machines never crash on it).
private func getPrefInt(_ context: CpContext?, _ key: String, _ defaultValue: Int) -> Int {
    context?.getPref(key, defaultValue) ?? defaultValue
}

public final class ChangeLineSM: LineStateMachine {
    /// `R.id.*` values used as preference values (exact numbers from the decompiled `R.java`).
    public enum RID {
        public static let FROM_ANY = 0x7F09_00A9
        public static let FROM_BOUNDARY = 0x7F09_00AA
        public static let FROM_FLAT = 0x7F09_00AB
        public static let FROM_MOUNTAIN = 0x7F09_00AC
        public static let FROM_VALLEY = 0x7F09_00AD
        public static let TO_BOUNDARY = 0x7F09_00AE
        public static let TO_FLAT = 0x7F09_00AF
        public static let TO_FLIP = 0x7F09_00B0
        public static let TO_MOUNTAIN = 0x7F09_00B1
        public static let TO_VALLEY = 0x7F09_00B2
    }

    public static let PREF_KEY_PAINT_CHANGE_LINE_TYPE_FROM = "PaintCpFragment.changeLineTypeFrom"
    public static let PREF_KEY_PAINT_CHANGE_LINE_TYPE_TO = "PaintCpFragment.changeLineTypeTo"

    private var prefFromTypeMap: [Int: LineType] = [:]
    private var prefToTypeMap: [Int: LineType] = [:]

    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.CHANGE_LINE.rawValue,
            directSelectionEnabled: directSelectionEnabled
        )
        prefFromTypeMap[RID.FROM_MOUNTAIN] = .mountain
        prefFromTypeMap[RID.FROM_VALLEY] = .valley
        prefFromTypeMap[RID.FROM_FLAT] = .flat
        prefFromTypeMap[RID.FROM_BOUNDARY] = .boundary
        prefToTypeMap[RID.TO_MOUNTAIN] = .mountain
        prefToTypeMap[RID.TO_VALLEY] = .valley
        prefToTypeMap[RID.TO_FLAT] = .flat
        prefToTypeMap[RID.TO_BOUNDARY] = .boundary
    }

    public func changeSingleLine(_ b: LineType, _ b2: LineType, _ oriLine: OriLine) -> HistoryItem {
        let historyItem = HistoryItem()
        historyItem.changeLines.append(HistoryTypeChange(oriLine, b, b2))
        oriLine.setType(b2)
        return historyItem
    }

    public func getToType(_ i: Int, _ b: LineType) -> LineType {
        if let b2 = prefToTypeMap[i] {
            return b2
        }
        if i != RID.TO_FLIP {
            return .undefined
        }
        if b == .mountain {
            return .valley
        }
        return b == .valley ? .mountain : .undefined
    }

    public func prepareChangeSingleLine(_ i: Int, _ i2: Int, _ oriLine: OriLine) -> HistoryItem {
        let bType = oriLine.type()
        if i != RID.FROM_ANY && bType != prefFromTypeMap[i] {
            return HistoryItem()
        }
        let toType = getToType(i2, bType)
        return (toType == .undefined || bType == toType)
            ? HistoryItem()
            : changeSingleLine(bType, toType, oriLine)
    }

    public override func doBatchLineOperationSet(
        _ context: CpContext?,
        _ creasePattern: CreasePattern,
        _ set: JavaSet<OriLine>
    ) -> HistoryGroup {
        let i = getPrefInt(
            context, ChangeLineSM.PREF_KEY_PAINT_CHANGE_LINE_TYPE_FROM, ChangeLineSM.RID.FROM_ANY
        )
        let i2 = getPrefInt(
            context, ChangeLineSM.PREF_KEY_PAINT_CHANGE_LINE_TYPE_TO, ChangeLineSM.RID.TO_MOUNTAIN
        )
        let historyGroup = HistoryGroup(getToolType())
        let iterator = set.iterator()
        while iterator.hasNext() {
            historyGroup.add(prepareChangeSingleLine(i, i2, iterator.next()))
        }
        return historyGroup
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        let oriLine = getState().linesPicked.toArray()[0]
        let from = getPrefInt(
            context, ChangeLineSM.PREF_KEY_PAINT_CHANGE_LINE_TYPE_FROM, ChangeLineSM.RID.FROM_ANY
        )
        let to = getPrefInt(
            context, ChangeLineSM.PREF_KEY_PAINT_CHANGE_LINE_TYPE_TO, ChangeLineSM.RID.TO_MOUNTAIN
        )
        let historyGroup = HistoryGroup(getToolType())
        historyGroup.add(prepareChangeSingleLine(from, to, oriLine))
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        ChangeLineSM(getDirectSelectionEnabled())
    }

    public override func hasBatchLineOperation() -> Bool { true }
}
