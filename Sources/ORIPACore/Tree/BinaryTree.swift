// Port of `com.origamitoolbox.oripa.tree.BinaryTree` (oripa-port src/js/core/tree/BinaryTree.js).
import Foundation

open class BinaryTree {
    private var _root: (any BinaryNode)?

    public init() {}

    public func clear() {
        _root = nil
    }

    public func getMaxNode(_ binaryNode: (any BinaryNode)?) -> (any BinaryNode)? {
        guard var node = binaryNode else { return nil }
        while let right = node.right() {
            node = right
        }
        return node
    }

    public func getMinNode(_ binaryNode: (any BinaryNode)?) -> (any BinaryNode)? {
        guard var node = binaryNode else { return nil }
        while let left = node.left() {
            node = left
        }
        return node
    }

    public func isEmpty() -> Bool {
        _root == nil
    }

    public func iterator() -> BinaryIterator {
        BinaryIterator(_root)
    }

    public func root() -> (any BinaryNode)? {
        _root
    }

    public func setRoot(_ binaryNode: (any BinaryNode)?) {
        _root = binaryNode
    }

    /// Java abstract `updateNode(BinaryNode)`; overridden by AVL/red-black trees.
    open func updateNode(_ binaryNode: any BinaryNode) {
        fatalError("abstract: BinaryTree.updateNode")
    }
}
