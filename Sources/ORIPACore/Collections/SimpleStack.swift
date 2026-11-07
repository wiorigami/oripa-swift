// Port of `com.origamitoolbox.oripa.util.SimpleStack<E>` (oripa-port src/js/core/util/SimpleStack.js).
import Foundation

public final class SimpleStackNode<Element>: StackIteratorNode {
    fileprivate var _next: SimpleStackNode<Element>?
    fileprivate var _value: Element

    public init(_ value: Element) {
        self._value = value
    }

    public func next() -> SimpleStackNode<Element>? { _next }
    public func setNext(_ stackNode: SimpleStackNode<Element>?) { _next = stackNode }
    public func value() -> Element { _value }
}

public final class SimpleStack<Element>: Stack {
    private var _head: SimpleStackNode<Element>?

    public init() {}

    public func clear() {
        _head = nil
    }

    public func isEmpty() -> Bool { _head == nil }

    public func size() -> Int {
        var count = 0
        var node = _head
        while node != nil {
            count += 1
            node = node?.next()
        }
        return count
    }

    public var count: Int { size() }

    public func iterator() -> SimpleStackIterator<SimpleStackNode<Element>> {
        SimpleStackIterator(_head)
    }

    public func peek() throws -> Element {
        guard let head = _head else { throw CoreError.emptyStack }
        return head.value()
    }

    @discardableResult
    public func pop() throws -> Element {
        guard let head = _head else { throw CoreError.emptyStack }
        let value = head.value()
        _head = head.next()
        return value
    }

    public func push(_ e: Element) {
        let node = SimpleStackNode(e)
        node.setNext(_head)
        _head = node
    }
}
