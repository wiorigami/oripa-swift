// Port of `com.origamitoolbox.oripa.util.FixedStack<E>` (oripa-port src/js/core/util/FixedStack.js).
// Bounded stack: pushing into a full stack drops the oldest entry.
import Foundation

public final class DoubleLinkStackNode<Element>: StackIteratorNode {
    fileprivate var _value: Element
    fileprivate var _prev: DoubleLinkStackNode<Element>?
    fileprivate var _next: DoubleLinkStackNode<Element>?

    public init(_ value: Element) {
        self._value = value
    }

    public func next() -> DoubleLinkStackNode<Element>? { _next }
    public func prev() -> DoubleLinkStackNode<Element>? { _prev }
    public func setNext(_ stackNode: DoubleLinkStackNode<Element>?) { _next = stackNode }
    public func setPrev(_ stackNode: DoubleLinkStackNode<Element>?) { _prev = stackNode }
    public func value() -> Element { _value }
}

public final class FixedStack<Element>: Stack {
    private let _maxSize: Int
    private var _head: DoubleLinkStackNode<Element>?
    private var _tail: DoubleLinkStackNode<Element>?
    private var _size = 0

    public init(_ maxSize: Int) {
        self._maxSize = maxSize
    }

    public func maxSize() -> Int { _maxSize }

    public func clear() {
        _head = nil
        _tail = nil
        _size = 0
    }

    public func isEmpty() -> Bool { _head == nil }

    public func size() -> Int { _size }
    public var count: Int { _size }

    public func iterator() -> SimpleStackIterator<DoubleLinkStackNode<Element>> {
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
        if let newHead = _head {
            newHead.setPrev(nil)
        }
        _size -= 1
        return value
    }

    public func push(_ e: Element) {
        if _size == _maxSize {
            _tail = _tail?.prev()
            _tail?.setNext(nil)
            _size -= 1
        }
        let node = DoubleLinkStackNode(e)
        node.setNext(_head)
        if isEmpty() {
            _tail = node
        } else {
            _head?.setPrev(node)
        }
        _head = node
        _size += 1
    }
}
