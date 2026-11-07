// Port of `com.origamitoolbox.oripa.model.history.HistoryGroup`
// (oripa-port src/js/core/model/history/HistoryGroup.js).
//
// The Java constructor takes the tool type byte but does not store it (the JS port keeps the
// same signature and drops the value).
import Foundation

public final class HistoryGroup {
    public var historyItems: [HistoryItem]

    public init(_ toolType: Int) {
        self.historyItems = []
    }

    public init() {
        self.historyItems = []
    }

    /// Java `add(HistoryItem)`: null/empty items are ignored.
    public func add(_ historyItem: HistoryItem?) {
        guard let historyItem, !historyItem.isEmpty() else { return }
        historyItems.append(historyItem)
    }

    public func addAll(_ list: [HistoryItem]) {
        for item in list { add(item) }
    }

    public func isEmpty() -> Bool { historyItems.isEmpty }
    public func size() -> Int { historyItems.count }

    public func iterator() -> JavaIterator<HistoryItem> {
        JavaIterator(historyItems)
    }

    /// Java `ListIterator` positioned at the end (reverse traversal used by undo).
    public func listIterator() -> HistoryGroupListIterator {
        HistoryGroupListIterator(historyItems)
    }
}

/// Port of the JS `listIterator()` object: `java.util.ListIterator` starting at the end.
public final class HistoryGroupListIterator {
    private let list: [HistoryItem]
    private var index: Int

    public init(_ list: [HistoryItem]) {
        self.list = list
        self.index = list.count
    }

    public func hasPrevious() -> Bool { index > 0 }

    public func previous() -> HistoryItem? {
        guard index > 0 else { return nil }
        index -= 1
        return list[index]
    }

    public func hasNext() -> Bool { index < list.count }

    public func next() -> HistoryItem? {
        guard index < list.count else { return nil }
        defer { index += 1 }
        return list[index]
    }

    public func nextIndex() -> Int { index }
    public func previousIndex() -> Int { index - 1 }
}
