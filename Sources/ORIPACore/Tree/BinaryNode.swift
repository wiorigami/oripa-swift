// Port of `com.origamitoolbox.oripa.tree.BinaryNode` (oripa-port src/js/core/tree/BinaryNode.js).
//
// Java declares a marker interface; the JS port relies on duck typing. Swift needs the
// requirements spelled out, so they live here. `RedBlackNode` adds the parent/colour
// protocol members used by the red-black tree; the AVL family uses the concrete
// `AvlNode` class instead (it owns the height field).
import Foundation

public protocol BinaryNode: AnyObject {
    func left() -> (any BinaryNode)?
    func right() -> (any BinaryNode)?
    func setLeft(_ node: (any BinaryNode)?)
    func setRight(_ node: (any BinaryNode)?)
    func compareTo(_ other: any BinaryNode) -> Int
}

/// Java `RedBlackNode` (interface): BinaryNode + parent pointer + red/black colour.
public protocol RedBlackNode: BinaryNode {
    func parent() -> (any RedBlackNode)?
    func setParent(_ node: (any RedBlackNode)?)
    func isBlack() -> Bool
    func isRed() -> Bool
    func setBlack()
    func setRed()
    func setIsBlack(_ value: Bool)
}

/// Convenience identity comparison for class-bound existential nodes.
@inline(__always)
public func binaryNodesIdentical(_ a: (any BinaryNode)?, _ b: (any BinaryNode)?) -> Bool {
    switch (a, b) {
    case (nil, nil): return true
    case let (lhs?, rhs?): return (lhs as AnyObject) === (rhs as AnyObject)
    default: return false
    }
}

@inline(__always)
public func redBlackNodesIdentical(_ a: (any RedBlackNode)?, _ b: (any RedBlackNode)?) -> Bool {
    switch (a, b) {
    case (nil, nil): return true
    case let (lhs?, rhs?): return (lhs as AnyObject) === (rhs as AnyObject)
    default: return false
    }
}
