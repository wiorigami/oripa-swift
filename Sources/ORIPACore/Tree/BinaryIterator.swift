// Port of `com.origamitoolbox.oripa.tree.BinaryIterator` (oripa-port src/js/core/tree/BinaryIterator.js).
//
// In-order iterator built on the tree's left-child stack (Java `SimpleStack`).
import Foundation

public final class BinaryIterator {
    private let stack = SimpleStack<any BinaryNode>()

    public init(_ binaryNode: (any BinaryNode)?) {
        var node = binaryNode
        while let current = node {
            stack.push(current)
            node = current.left()
        }
    }

    public func hasNext() -> Bool {
        !stack.isEmpty()
    }

    public func next() -> any BinaryNode {
        guard let binaryNode = try? stack.pop() else {
            fatalError("BinaryIterator.next() on exhausted iterator")
        }
        var right = binaryNode.right()
        while let current = right {
            stack.push(current)
            right = current.left()
        }
        return binaryNode
    }
}
