// Port of `com.origamitoolbox.oripa.tree.AvlNestedTree<T>`
// (oripa-port src/js/core/tree/AvlNestedTree.js) — self-balancing AVL tree algorithms.
import Foundation

open class AvlNestedTree<T: AnyObject>: BinaryNestedTree<T> {
    public override init() {
        super.init()
    }

    // MARK: - Balancing

    public func balance(_ avlNode: AvlNode) -> AvlNode {
        let balanceFactor = getBalanceFactor(avlNode)
        if balanceFactor > 1 && getBalanceFactor(avlNode.left() as? AvlNode) > 0 {
            return rightRotate(avlNode)
        }
        if balanceFactor < -1 && getBalanceFactor(avlNode.right() as? AvlNode) < 0 {
            return leftRotate(avlNode)
        }
        if balanceFactor > 1 && getBalanceFactor(avlNode.left() as? AvlNode) <= 0 {
            avlNode.setLeft(leftRotate(avlNode.left() as! AvlNode))
            return rightRotate(avlNode)
        }
        if balanceFactor >= -1 || getBalanceFactor(avlNode.right() as? AvlNode) < 0 {
            return avlNode
        }
        avlNode.setRight(rightRotate(avlNode.right() as! AvlNode))
        return leftRotate(avlNode)
    }

    public func getBalanceFactor(_ avlNode: AvlNode?) -> Int {
        guard let avlNode else { return 0 }
        return getHeight(avlNode.left() as? AvlNode) - getHeight(avlNode.right() as? AvlNode)
    }

    public func getHeight(_ avlNode: AvlNode?) -> Int {
        guard let avlNode else { return -1 }
        return avlNode.height()
    }

    public func insertRecurse(_ avlNode: AvlNode?, _ avlNode2: AvlNode, _ t: T) -> AvlNode? {
        guard let avlNode else { return avlNode2 }
        let comparison = avlNode2.compareTo(avlNode)
        if comparison < 0 {
            avlNode.setLeft(insertRecurse(avlNode.left() as? AvlNode, avlNode2, t))
        } else if comparison <= 0 {
            insertIntoNested(avlNode, t)
            return avlNode
        } else {
            avlNode.setRight(insertRecurse(avlNode.right() as? AvlNode, avlNode2, t))
        }
        updateNode(avlNode)
        return balance(avlNode)
    }

    public func removeRecurse(_ avlNode: AvlNode?, _ avlNode2: AvlNode, _ t: T?) -> AvlNode? {
        guard var avlNode else { return nil }
        let comparison = avlNode2.compareTo(avlNode)
        if comparison < 0 {
            avlNode.setLeft(removeRecurse(avlNode.left() as? AvlNode, avlNode2, t))
        } else if comparison > 0 {
            avlNode.setRight(removeRecurse(avlNode.right() as? AvlNode, avlNode2, t))
        } else {
            if let t, removeInNested(avlNode, t) {
                return avlNode
            }
            if avlNode.left() == nil && avlNode.right() == nil {
                return nil
            }
            if avlNode.left() == nil {
                return avlNode.right() as? AvlNode
            }
            if avlNode.right() == nil {
                return avlNode.left() as? AvlNode
            }
            guard let avlNode3 = getMinNode(avlNode.right()) as? AvlNode else {
                return avlNode
            }
            avlNode3.setRight(removeRecurse(avlNode3.right() as? AvlNode, avlNode3, nil))
            avlNode3.setLeft(avlNode.left())
            avlNode = avlNode3
        }
        updateNode(avlNode)
        return balance(avlNode)
    }

    public func leftRotate(_ avlNode: AvlNode) -> AvlNode {
        guard let avlNodeRight = avlNode.right() as? AvlNode else { return avlNode }
        avlNode.setRight(avlNodeRight.left())
        avlNodeRight.setLeft(avlNode)
        updateNode(avlNode)
        updateNode(avlNodeRight)
        return avlNodeRight
    }

    public func rightRotate(_ avlNode: AvlNode) -> AvlNode {
        guard let avlNodeLeft = avlNode.left() as? AvlNode else { return avlNode }
        avlNode.setLeft(avlNodeLeft.right())
        avlNodeLeft.setRight(avlNode)
        updateNode(avlNode)
        updateNode(avlNodeLeft)
        return avlNodeLeft
    }

    public func updateHeight(_ avlNode: AvlNode) {
        avlNode.setHeight(max(getHeight(avlNode.left() as? AvlNode), getHeight(avlNode.right() as? AvlNode)) + 1)
    }

    open override func updateNode(_ binaryNode: any BinaryNode) {
        guard let avlNode = binaryNode as? AvlNode else { return }
        updateHeight(avlNode)
    }

    // MARK: - Public tree operations

    open override func insert(_ t: T) {
        guard let node = newNode(t) as? AvlNode else {
            fatalError("AvlNestedTree.newNode must return an AvlNode")
        }
        setRoot(insertRecurse(root() as? AvlNode, node, t))
    }

    open override func remove(_ t: T) {
        guard let node = newNode(t) as? AvlNode else {
            fatalError("AvlNestedTree.newNode must return an AvlNode")
        }
        setRoot(removeRecurse(root() as? AvlNode, node, t))
    }
}
