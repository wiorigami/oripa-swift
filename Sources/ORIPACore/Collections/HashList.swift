// Port of `com.origamitoolbox.oripa.util.HashList<E>` (oripa-port src/js/core/util/HashList.js).
//
// List with O(1) `contains` backed by a value-semantics map, plus lazy index bookkeeping exactly
// like the Java/JS reference.
import Foundation

public final class HashList<Element: AnyObject> {
    public private(set) var mList: [Element] = []
    public let mMap = JavaMap<Element, Int>()
    public private(set) var indexed = true

    public init() {}

    /// Java `getNextIndex`.
    public func getNextIndex(_ e: Element) throws -> Int {
        guard mMap.containsKey(e) else {
            throw CoreError.noSuchElement("NoSuchElementException")
        }
        if !indexed { updateIndex() }
        guard let index = mMap.get(e) else {
            throw CoreError.noSuchElement("NoSuchElementException")
        }
        return GeomUtil.clamp(index + 1, size())
    }

    /// Java `getPrevIndex`.
    public func getPrevIndex(_ e: Element) throws -> Int {
        guard mMap.containsKey(e) else {
            throw CoreError.noSuchElement("NoSuchElementException")
        }
        if !indexed { updateIndex() }
        guard let index = mMap.get(e) else {
            throw CoreError.noSuchElement("NoSuchElementException")
        }
        return GeomUtil.clamp(index - 1, size())
    }

    public func updateIndex() {
        for index in 0..<mList.count {
            mMap.put(mList[index], index)
        }
        indexed = true
    }

    /// Java `add(E)`.
    @discardableResult
    public func add(_ e: Element) -> Bool {
        if mMap.containsKey(e) { return false }
        mMap.put(e, mList.count)
        mList.append(e)
        return true
    }

    /// Java `add(int, E)`.
    @discardableResult
    public func add(_ index: Int, _ e: Element) -> Bool {
        if mMap.containsKey(e) { return false }
        mList.insert(e, at: index)
        mMap.put(e, -1)
        indexed = false
        return true
    }

    public func clear() {
        mList.removeAll()
        mMap.clear()
        indexed = true
    }

    public func contains(_ e: Element) -> Bool { mMap.containsKey(e) }

    public func get(_ index: Int) -> Element? {
        guard index >= 0 && index < mList.count else { return nil }
        return mList[index]
    }

    public func getElement(_ e: Element) throws -> Element {
        guard mMap.containsKey(e) else { throw CoreError.noSuchElement("NoSuchElementException") }
        let index = try getIndex(e)
        guard let element = get(index) else { throw CoreError.noSuchElement("NoSuchElementException") }
        return element
    }

    public func getIndex(_ e: Element) throws -> Int {
        guard mMap.containsKey(e) else { throw CoreError.noSuchElement("NoSuchElementException") }
        if !indexed { updateIndex() }
        guard let index = mMap.get(e) else { throw CoreError.noSuchElement("NoSuchElementException") }
        return index
    }

    public func getList() -> [Element] { mList }

    public func getNext(_ e: Element) throws -> Element? {
        guard mMap.containsKey(e) else { throw CoreError.noSuchElement("NoSuchElementException") }
        return get(try getNextIndex(e))
    }

    public func getPrev(_ e: Element) throws -> Element? {
        guard mMap.containsKey(e) else { throw CoreError.noSuchElement("NoSuchElementException") }
        return get(try getPrevIndex(e))
    }

    public func iterator() -> JavaIterator<Element> { JavaIterator(mList) }

    /// Java `remove(Object)`: throws `NoSuchElementException` when absent.
    public func remove(_ e: Element) throws {
        if !indexed { updateIndex() }
        guard let index = mMap.remove(e) else { throw CoreError.noSuchElement("NoSuchElementException") }
        mList.remove(at: index)
        indexed = false
    }

    @discardableResult
    public func removeLast() -> Element? {
        guard let e = mList.popLast() else { return nil }
        mMap.remove(e)
        return e
    }

    public func size() -> Int { mList.count }
    public var count: Int { mList.count }
    public func isEmpty() -> Bool { mList.isEmpty }

    /// Java `Collections.sort` / JS `sort(comparator)` (comparator returns negative/zero/positive).
    public func sort(_ comparator: (Element, Element) -> Int) {
        mList.sort { comparator($0, $1) < 0 }
        updateIndex()
        indexed = true
    }

    public func toString() -> String {
        "[" + mList.map { String(describing: $0) }.joined(separator: ", ") + "]"
    }
}
