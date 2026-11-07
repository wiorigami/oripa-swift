// Port of the support class `util/JavaCollections.js` from the reference port, which emulates
// `java.util.HashMap` / `HashSet` / `LinkedHashSet` value semantics (identity-based Swift
// `Set`/`Dictionary` would silently change the ported algorithms).
//
// Iteration order follows the JS reference exactly: buckets are visited in first-insertion
// order of their hash value (a JS `Map` iterates in insertion order), and objects that do not
// implement `JavaHashable` fall back to Java `Object` identity hashing with sequential ids.
import Foundation

/// A Java object with `hashCode()`/`equals(Object)` value semantics.
public protocol JavaHashable: AnyObject {
    func hashCode() -> Int
    func equals(_ other: Any?) -> Bool
}

/// Hash/equals helpers shared by `JavaMap`, `JavaSet` and `HashList`.
public enum JavaHash {
    /// JS `| 0`: truncate to a signed 32-bit integer (Java `int`).
    @inline(__always)
    public static func truncate(_ value: Int) -> Int {
        Int(Int32(truncatingIfNeeded: value))
    }

    /// JS `hashOf(value)`.
    public static func value(_ object: AnyObject?) -> Int {
        guard let object else { return 0 }
        if let java = object as? JavaHashable {
            return truncate(java.hashCode())
        }
        if let string = object as? String {
            return hashString(string)
        }
        return identityHash(object)
    }

    /// JS `equalsOf(a, b)`.
    public static func equals(_ a: AnyObject?, _ b: AnyObject?) -> Bool {
        if let a, let b, a === b { return true }
        guard let a, let b else { return false }
        if let java = a as? JavaHashable {
            return java.equals(b)
        }
        return false
    }

    private static func hashString(_ string: String) -> Int {
        var hash: Int32 = 0
        for scalar in string.unicodeScalars {
            hash = hash &* 31 &+ Int32(truncatingIfNeeded: scalar.value)
        }
        return Int(hash)
    }

    // Java `Object.hashCode()` identity fallback (JS WeakMap sequential ids).
    private static var identityIds: [ObjectIdentifier: Int] = [:]
    private static var nextIdentityId: Int = 1

    private static func identityHash(_ object: AnyObject) -> Int {
        let id = ObjectIdentifier(object)
        if let value = identityIds[id] { return value }
        let value = nextIdentityId
        nextIdentityId += 1
        identityIds[id] = value
        return value
    }
}

/// `java.util.HashMap<K, V>` with value-based keys.
public final class JavaMap<Key: AnyObject, Value> {
    private var buckets: [Int: [(key: Key, value: Value)]] = [:]
    private var bucketOrder: [Int] = []
    private var _size = 0

    public init() {}

    /// Java `put`; returns the previous value (JS `null` -> `nil`).
    @discardableResult
    public func put(_ key: Key, _ value: Value) -> Value? {
        let hash = JavaHash.value(key)
        if var bucket = buckets[hash] {
            for index in bucket.indices where JavaHash.equals(bucket[index].key, key) {
                let old = bucket[index].value
                bucket[index].value = value
                buckets[hash] = bucket
                return old
            }
            bucket.append((key: key, value: value))
            buckets[hash] = bucket
        } else {
            bucketOrder.append(hash)
            buckets[hash] = [(key: key, value: value)]
        }
        _size += 1
        return nil
    }

    public func get(_ key: Key) -> Value? {
        guard let bucket = buckets[JavaHash.value(key)] else { return nil }
        for entry in bucket where JavaHash.equals(entry.key, key) {
            return entry.value
        }
        return nil
    }

    public func containsKey(_ key: Key) -> Bool {
        guard let bucket = buckets[JavaHash.value(key)] else { return false }
        return bucket.contains { JavaHash.equals($0.key, key) }
    }

    @discardableResult
    public func remove(_ key: Key) -> Value? {
        let hash = JavaHash.value(key)
        guard var bucket = buckets[hash],
              let index = bucket.firstIndex(where: { JavaHash.equals($0.key, key) }) else { return nil }
        let old = bucket[index].value
        bucket.remove(at: index)
        _size -= 1
        if bucket.isEmpty {
            buckets[hash] = nil
            bucketOrder.removeAll { $0 == hash }
        } else {
            buckets[hash] = bucket
        }
        return old
    }

    public func clear() {
        buckets.removeAll()
        bucketOrder.removeAll()
        _size = 0
    }

    public func size() -> Int { _size }
    public var count: Int { _size }
    public func isEmpty() -> Bool { _size == 0 }

    /// Java `values()` in JS reference iteration order.
    public func values() -> [Value] {
        var result: [Value] = []
        for hash in bucketOrder {
            if let bucket = buckets[hash] {
                for entry in bucket { result.append(entry.value) }
            }
        }
        return result
    }

    public func keySet() -> [Key] {
        var result: [Key] = []
        for hash in bucketOrder {
            if let bucket = buckets[hash] {
                for entry in bucket { result.append(entry.key) }
            }
        }
        return result
    }

    public func keys() -> [Key] { keySet() }

    public func entries() -> [(key: Key, value: Value)] {
        var result: [(key: Key, value: Value)] = []
        for hash in bucketOrder {
            if let bucket = buckets[hash] {
                for entry in bucket { result.append(entry) }
            }
        }
        return result
    }

    public func forEach(_ body: (Key, Value) -> Void) {
        for hash in bucketOrder {
            if let bucket = buckets[hash] {
                for entry in bucket { body(entry.key, entry.value) }
            }
        }
    }

    public func iterator() -> JavaIterator<(key: Key, value: Value)> {
        JavaIterator(entries())
    }
}

/// `java.util.HashSet<E>` with value-based keys.
public final class JavaSet<Element: AnyObject> {
    private var buckets: [Int: [Element]] = [:]
    private var bucketOrder: [Int] = []
    private var _size = 0

    public init() {}

    @discardableResult
    public func add(_ value: Element) -> Bool {
        let hash = JavaHash.value(value)
        if var bucket = buckets[hash] {
            if bucket.contains(where: { JavaHash.equals($0, value) }) { return false }
            bucket.append(value)
            buckets[hash] = bucket
        } else {
            bucketOrder.append(hash)
            buckets[hash] = [value]
        }
        _size += 1
        return true
    }

    @discardableResult
    public func addAll(_ values: [Element]) -> Bool {
        var changed = false
        for value in values where add(value) { changed = true }
        return changed
    }

    public func contains(_ value: Element) -> Bool {
        guard let bucket = buckets[JavaHash.value(value)] else { return false }
        return bucket.contains { JavaHash.equals($0, value) }
    }

    @discardableResult
    public func remove(_ value: Element) -> Bool {
        let hash = JavaHash.value(value)
        guard var bucket = buckets[hash],
              let index = bucket.firstIndex(where: { JavaHash.equals($0, value) }) else { return false }
        bucket.remove(at: index)
        _size -= 1
        if bucket.isEmpty {
            buckets[hash] = nil
            bucketOrder.removeAll { $0 == hash }
        } else {
            buckets[hash] = bucket
        }
        return true
    }

    @discardableResult
    public func removeAll(_ values: [Element]) -> Bool {
        var changed = false
        for value in values where remove(value) { changed = true }
        return changed
    }

    public func clear() {
        buckets.removeAll()
        bucketOrder.removeAll()
        _size = 0
    }

    public func size() -> Int { _size }
    public var count: Int { _size }
    public func isEmpty() -> Bool { _size == 0 }

    /// JS reference iteration order (bucket first-insertion order).
    public func values() -> [Element] {
        var result: [Element] = []
        for hash in bucketOrder {
            if let bucket = buckets[hash] { result.append(contentsOf: bucket) }
        }
        return result
    }

    public func toArray() -> [Element] { values() }

    public func iterator() -> JavaIterator<Element> { JavaIterator(values()) }

    public func forEach(_ body: (Element) -> Void) {
        for value in values() { body(value) }
    }
}

/// `java.util.LinkedHashSet<E>`: insertion ordered.
public final class JavaLinkedSet<Element: AnyObject> {
    private var list: [Element] = []
    private var buckets: [Int: [Element]] = [:]

    public init() {}

    @discardableResult
    public func add(_ value: Element) -> Bool {
        let hash = JavaHash.value(value)
        if var bucket = buckets[hash] {
            if bucket.contains(where: { JavaHash.equals($0, value) }) { return false }
            bucket.append(value)
            buckets[hash] = bucket
        } else {
            buckets[hash] = [value]
        }
        list.append(value)
        return true
    }

    @discardableResult
    public func addAll(_ values: [Element]) -> Bool {
        var changed = false
        for value in values where add(value) { changed = true }
        return changed
    }

    public func contains(_ value: Element) -> Bool {
        guard let bucket = buckets[JavaHash.value(value)] else { return false }
        return bucket.contains { JavaHash.equals($0, value) }
    }

    @discardableResult
    public func remove(_ value: Element) -> Bool {
        let hash = JavaHash.value(value)
        guard var bucket = buckets[hash],
              let bucketIndex = bucket.firstIndex(where: { JavaHash.equals($0, value) }) else { return false }
        let removed = bucket.remove(at: bucketIndex)
        if bucket.isEmpty {
            buckets[hash] = nil
        } else {
            buckets[hash] = bucket
        }
        if let listIndex = list.firstIndex(where: { $0 === removed }) {
            list.remove(at: listIndex)
        }
        return true
    }

    @discardableResult
    public func removeAll(_ values: [Element]) -> Bool {
        var changed = false
        for value in values where remove(value) { changed = true }
        return changed
    }

    public func clear() {
        buckets.removeAll()
        list.removeAll()
    }

    public func size() -> Int { list.count }
    public var count: Int { list.count }
    public func isEmpty() -> Bool { list.isEmpty }

    public func values() -> [Element] { list }
    public func toArray() -> [Element] { list }
    public func iterator() -> JavaIterator<Element> { JavaIterator(list) }

    public func forEach(_ body: (Element) -> Void) {
        for value in list { body(value) }
    }
}

/// Java-style iterator (`hasNext()`/`next()`); `next()` on an exhausted iterator traps like
/// Java's `NoSuchElementException` would throw.
public final class JavaIterator<Element> {
    private let values: [Element]
    private var index = 0

    public init(_ values: [Element]) {
        self.values = values
    }

    public func hasNext() -> Bool { index < values.count }

    public func next() -> Element {
        precondition(index < values.count, "NoSuchElementException")
        defer { index += 1 }
        return values[index]
    }

    /// Non-trapping variant for ported code that already checks `hasNext()`.
    public func nextOrNil() -> Element? {
        guard index < values.count else { return nil }
        defer { index += 1 }
        return values[index]
    }
}
