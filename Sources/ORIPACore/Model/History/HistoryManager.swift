// Port of `com.origamitoolbox.oripa.model.history.HistoryManager`
// (oripa-port src/js/core/model/history/HistoryManager.js): 50-step undo/redo stacks.
import Foundation

public final class HistoryManager {
    public let maxHistory = 50
    public let undoHistory: FixedStack<HistoryGroup>
    public let redoHistory: FixedStack<HistoryGroup>

    public init() {
        self.undoHistory = FixedStack(50)
        self.redoHistory = FixedStack(50)
    }

    public func clearAll() {
        undoHistory.clear()
        redoHistory.clear()
    }

    public func hasRedo() -> Bool { !redoHistory.isEmpty() }
    public func hasUndo() -> Bool { !undoHistory.isEmpty() }

    /// Java `newBranch(HistoryGroup)`: pushes an undo entry and invalidates the redo stack.
    public func newBranch(_ historyGroup: HistoryGroup) {
        undoHistory.push(historyGroup)
        redoHistory.clear()
    }

    /// Java `redo(CreasePattern)`: applies the next redo group in insertion order.
    public func redo(_ creasePattern: CreasePattern) {
        guard !redoHistory.isEmpty(), let group = try? redoHistory.pop() else { return }
        undoHistory.push(group)
        for historyItem in group.historyItems {
            for change in historyItem.changeLines {
                creasePattern.changeLineType(change.changedLine, change.toType)
            }
            for oriLine in historyItem.oldLines {
                creasePattern.removeLine(oriLine)
            }
            for oriLine in historyItem.newLines {
                _ = creasePattern.addLineNoCheck(oriLine)
            }
        }
    }

    /// Java `undo(CreasePattern)`: reverts the last group in reverse item order.
    public func undo(_ creasePattern: CreasePattern) {
        guard !undoHistory.isEmpty(), let group = try? undoHistory.pop() else { return }
        redoHistory.push(group)
        let listIterator = group.listIterator()
        while listIterator.hasPrevious() {
            guard let historyItem = listIterator.previous() else { break }
            for oriLine in historyItem.newLines {
                creasePattern.removeLine(oriLine)
            }
            for oriLine in historyItem.oldLines {
                _ = creasePattern.addLineNoCheck(oriLine)
            }
            for change in historyItem.changeLines {
                creasePattern.changeLineType(change.changedLine, change.fromType)
            }
        }
    }

    /// Undo group count (used by UI enabled states/tests).
    public func undoCount() -> Int { undoHistory.size() }
    public func redoCount() -> Int { redoHistory.size() }
}
