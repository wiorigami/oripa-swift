// Port of `com.origamitoolbox.oripa.model.history.HistoryItem`
// (oripa-port src/js/core/model/history/HistoryItem.js).
import Foundation

/// All changes a single tool action applied: type changes, removed (old) lines, added (new) lines.
public final class HistoryItem {
    public var changeLines: [HistoryTypeChange]
    public var oldLines: [OriLine]
    public var newLines: [OriLine]

    public init() {
        self.changeLines = []
        self.oldLines = []
        self.newLines = []
    }

    public func isEmpty() -> Bool {
        changeLines.isEmpty && oldLines.isEmpty && newLines.isEmpty
    }
}
