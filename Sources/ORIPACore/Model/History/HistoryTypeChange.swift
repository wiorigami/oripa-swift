// Port of `com.origamitoolbox.oripa.model.history.HistoryTypeChange`
// (oripa-port src/js/core/model/history/HistoryTypeChange.js).
import Foundation

/// One line whose type was changed by a tool; undo restores `fromType`, redo applies `toType`.
public final class HistoryTypeChange {
    public let changedLine: OriLine
    public let fromType: LineType
    public let toType: LineType

    public init(_ oriLine: OriLine, _ fromType: LineType, _ toType: LineType) {
        self.changedLine = oriLine
        self.fromType = fromType
        self.toType = toType
    }

    /// Convenience for call sites that keep Java `byte` line-type values.
    public convenience init(_ oriLine: OriLine, fromType: Int, toType: Int) {
        self.init(oriLine,
                  LineType(rawValue: fromType) ?? .undefined,
                  LineType(rawValue: toType) ?? .undefined)
    }
}
