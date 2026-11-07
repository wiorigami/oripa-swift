// Port of `com.origamitoolbox.oripa.util.SimpleStackIterator<E>`
// (oripa-port src/js/core/util/SimpleStackIterator.js).
//
// Generalized over the node type so it can iterate both `SimpleStack` and `FixedStack` nodes
// (the JS reference feeds either node kind into the same iterator).
import Foundation

/// Common shape of `SimpleStackNode` / `DoubleLinkStackNode`.
public protocol StackIteratorNode: AnyObject {
    associatedtype Value
    func next() -> Self?
    func value() -> Value
}

public final class SimpleStackIterator<Node: StackIteratorNode> {
    private var node: Node?

    public init(_ stackNode: Node?) {
        self.node = stackNode
    }

    public func hasNext() -> Bool { node != nil }

    public func next() -> Node.Value {
        guard let current = node else {
            preconditionFailure("NoSuchElementException")
        }
        let value = current.value()
        node = current.next()
        return value
    }
}
