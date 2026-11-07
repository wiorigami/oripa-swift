// Port of `com.origamitoolbox.oripa.tree.AvlNode` (oripa-port src/js/core/tree/AvlNode.js).
//
// Java `AvlNode` is an abstract class implementing `BinaryNode` and owning the node
// height. Concrete AVL node classes (line/point trees) subclass it.
import Foundation

open class AvlNode: BinaryNode {
    private var _height: Int = 0

    public init() {}

    public func height() -> Int {
        _height
    }

    public func setHeight(_ i: Int) {
        _height = i
    }

    open func left() -> (any BinaryNode)? {
        fatalError("abstract: AvlNode.left")
    }

    open func right() -> (any BinaryNode)? {
        fatalError("abstract: AvlNode.right")
    }

    open func setLeft(_ node: (any BinaryNode)?) {
        fatalError("abstract: AvlNode.setLeft")
    }

    open func setRight(_ node: (any BinaryNode)?) {
        fatalError("abstract: AvlNode.setRight")
    }

    open func compareTo(_ other: any BinaryNode) -> Int {
        fatalError("abstract: AvlNode.compareTo")
    }
}
