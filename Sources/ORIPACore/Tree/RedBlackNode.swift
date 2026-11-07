// Port of `com.origamitoolbox.oripa.tree.RedBlackNode` (marker) plus the shared node
// storage used by concrete red-black nodes (oripa-port src/js/core/tree/RedBlackNode.js).
//
// `RedBlackNode` is a protocol because one of the reference classes (`LineXNodeYTree` /
// `PointXNodeYTree`) is simultaneously a red-black *node* and a nested tree, which Swift's
// single inheritance cannot express with a base class.
import Foundation

/// Shared storage for standalone red-black nodes.
open class RedBlackNodeBase: RedBlackNode {
    private var _isBlack: Bool = false
    private var _parent: (any RedBlackNode)?
    private var _left: (any BinaryNode)?
    private var _right: (any BinaryNode)?

    public init() {}

    public func isBlack() -> Bool { _isBlack }
    public func isRed() -> Bool { !_isBlack }
    public func setBlack() { _isBlack = true }
    public func setRed() { _isBlack = false }
    public func setIsBlack(_ value: Bool) { _isBlack = value }

    public func parent() -> (any RedBlackNode)? { _parent }
    public func setParent(_ node: (any RedBlackNode)?) { _parent = node }

    public func left() -> (any BinaryNode)? { _left }
    public func right() -> (any BinaryNode)? { _right }
    public func setLeft(_ node: (any BinaryNode)?) { _left = node }
    public func setRight(_ node: (any BinaryNode)?) { _right = node }

    open func compareTo(_ other: any BinaryNode) -> Int {
        fatalError("abstract: RedBlackNode.compareTo")
    }
}
