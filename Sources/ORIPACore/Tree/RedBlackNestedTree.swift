// Port of `com.origamitoolbox.oripa.tree.RedBlackNestedTree<T>`
// (oripa-port src/js/core/tree/RedBlackNestedTree.js).
//
// NOTE: the JS port replaced jadx's broken `fixAfterInsert`/`fixAfterDeletion` with the
// standard CLRS fixups; the tree contract (ordering, balancing, updateNode hooks) is
// unchanged. This Swift port follows the JS reference exactly.
import Foundation

open class RedBlackNestedTree<T: AnyObject>: BinaryNestedTree<T> {
    public override init() {
        super.init()
    }

    @inline(__always)
    private func rb(_ node: (any BinaryNode)?) -> (any RedBlackNode)? {
        node as? any RedBlackNode
    }

    // MARK: - Colour helpers

    public func getIsBlack(_ node: (any RedBlackNode)?) -> Bool {
        node == nil || node!.isBlack()
    }

    public func getIsRed(_ node: (any RedBlackNode)?) -> Bool {
        node != nil && node!.isRed()
    }

    // MARK: - Insert fixup

    public func fixAfterInsert(_ node: any RedBlackNode) {
        var redBlackNode: any RedBlackNode = node
        while let parent = redBlackNode.parent(), parent.isRed() {
            guard let grand = parent.parent() else { break }
            if redBlackNodesIdentical(parent, rb(grand.left())) {
                let uncle = rb(grand.right())
                if let uncle, uncle.isRed() {
                    parent.setBlack()
                    uncle.setBlack()
                    grand.setRed()
                    redBlackNode = grand
                } else {
                    if redBlackNodesIdentical(redBlackNode, rb(parent.right())) {
                        redBlackNode = parent
                        leftRotate(redBlackNode)
                        guard let newParent = redBlackNode.parent(), let newGrand = newParent.parent() else { break }
                        newParent.setBlack()
                        newGrand.setRed()
                        rightRotate(newGrand)
                    } else {
                        parent.setBlack()
                        grand.setRed()
                        rightRotate(grand)
                    }
                }
            } else {
                let uncle = rb(grand.left())
                if let uncle, uncle.isRed() {
                    parent.setBlack()
                    uncle.setBlack()
                    grand.setRed()
                    redBlackNode = grand
                } else {
                    if redBlackNodesIdentical(redBlackNode, rb(parent.left())) {
                        redBlackNode = parent
                        rightRotate(redBlackNode)
                        guard let newParent = redBlackNode.parent(), let newGrand = newParent.parent() else { break }
                        newParent.setBlack()
                        newGrand.setRed()
                        leftRotate(newGrand)
                    } else {
                        parent.setBlack()
                        grand.setRed()
                        leftRotate(grand)
                    }
                }
            }
        }
        rootBlack()
    }

    private func rootBlack() {
        rb(root())?.setBlack()
    }

    // MARK: - Rotations

    public func leftRotate(_ redBlackNode: any RedBlackNode) {
        guard let right = rb(redBlackNode.right()) else { return }
        let left = rb(right.left())
        redBlackNode.setRight(left)
        right.setLeft(redBlackNode)
        if redBlackNodesIdentical(redBlackNode, rb(root())) {
            setRoot(right)
        } else if let parent = redBlackNode.parent(), redBlackNodesIdentical(redBlackNode, rb(parent.left())) {
            parent.setLeft(right)
        } else {
            redBlackNode.parent()?.setRight(right)
        }
        right.setParent(redBlackNode.parent())
        redBlackNode.setParent(right)
        left?.setParent(redBlackNode)
        updateNode(redBlackNode)
        updateNode(right)
    }

    public func rightRotate(_ redBlackNode: any RedBlackNode) {
        guard let left = rb(redBlackNode.left()) else { return }
        let right = rb(left.right())
        redBlackNode.setLeft(right)
        left.setRight(redBlackNode)
        if redBlackNodesIdentical(redBlackNode, rb(root())) {
            setRoot(left)
        } else if let parent = redBlackNode.parent(), redBlackNodesIdentical(redBlackNode, rb(parent.left())) {
            parent.setLeft(left)
        } else {
            redBlackNode.parent()?.setRight(left)
        }
        left.setParent(redBlackNode.parent())
        redBlackNode.setParent(left)
        right?.setParent(redBlackNode)
        updateNode(redBlackNode)
        updateNode(left)
    }

    // MARK: - Insert

    public func insertRecurse(
        _ redBlackNode: (any RedBlackNode)?,
        _ redBlackNode2: any RedBlackNode,
        _ t: T
    ) -> any RedBlackNode {
        guard let redBlackNode else { return redBlackNode2 }
        let comparison = redBlackNode2.compareTo(redBlackNode)
        if comparison < 0 {
            if let child = insertRecurse(rb(redBlackNode.left()), redBlackNode2, t) as? any RedBlackNode,
               redBlackNodesIdentical(child, redBlackNode2) {
                redBlackNode.setLeft(redBlackNode2)
                redBlackNode2.setParent(redBlackNode)
            }
        } else if comparison <= 0 {
            insertIntoNested(redBlackNode, t)
        } else if let child = insertRecurse(rb(redBlackNode.right()), redBlackNode2, t) as? any RedBlackNode,
                  redBlackNodesIdentical(child, redBlackNode2) {
            redBlackNode.setRight(redBlackNode2)
            redBlackNode2.setParent(redBlackNode)
        }
        updateNode(redBlackNode)
        return redBlackNode
    }

    public override func insert(_ t: T) {
        guard let node = newNode(t) as? any RedBlackNode else {
            fatalError("RedBlackNestedTree.newNode must return a RedBlackNode")
        }
        setRoot(insertRecurse(rb(root()), node, t))
        fixAfterInsert(node)
    }

    // MARK: - Deletion

    public func transplantSubTree(_ redBlackNode: any RedBlackNode, _ redBlackNode2: (any RedBlackNode)?) {
        if let parent = redBlackNode.parent() {
            if redBlackNodesIdentical(redBlackNode, rb(parent.left())) {
                parent.setLeft(redBlackNode2)
            } else {
                parent.setRight(redBlackNode2)
            }
        } else {
            setRoot(redBlackNode2)
        }
        redBlackNode2?.setParent(redBlackNode.parent())
    }

    public func fixAfterDeletion(
        _ redBlackNode: (any RedBlackNode)?,
        _ redBlackNodeParent: (any RedBlackNode)?,
        _ isLeftChild: Bool
    ) {
        var redBlackNode = redBlackNode
        var redBlackNodeParent = redBlackNodeParent
        var isLeftChild = isLeftChild
        while !redBlackNodesIdentical(redBlackNode, rb(root())), getIsBlack(redBlackNode) {
            if isLeftChild {
                guard let parent = redBlackNodeParent, let sibling = rb(parent.right()) else { break }
                var workingSibling: any RedBlackNode = sibling
                if workingSibling.isRed() {
                    workingSibling.setBlack()
                    parent.setRed()
                    leftRotate(parent)
                    guard let newSibling = rb(parent.right()) else { break }
                    workingSibling = newSibling
                }
                if getIsBlack(rb(workingSibling.left())), getIsBlack(rb(workingSibling.right())) {
                    workingSibling.setRed()
                    redBlackNode = parent
                    redBlackNodeParent = redBlackNode?.parent()
                    isLeftChild = redBlackNodeParent.map { redBlackNodesIdentical(redBlackNode, rb($0.left())) } ?? false
                } else {
                    if getIsBlack(rb(workingSibling.right())) {
                        rb(workingSibling.left())?.setBlack()
                        workingSibling.setRed()
                        rightRotate(workingSibling)
                        guard let newSibling = rb(parent.right()) else { break }
                        workingSibling = newSibling
                    }
                    workingSibling.setIsBlack(parent.isBlack())
                    parent.setBlack()
                    rb(workingSibling.right())?.setBlack()
                    leftRotate(parent)
                    redBlackNode = rb(root())
                    redBlackNodeParent = nil
                }
            } else {
                guard let parent = redBlackNodeParent, let sibling = rb(parent.left()) else { break }
                var workingSibling: any RedBlackNode = sibling
                if workingSibling.isRed() {
                    workingSibling.setBlack()
                    parent.setRed()
                    rightRotate(parent)
                    guard let newSibling = rb(parent.left()) else { break }
                    workingSibling = newSibling
                }
                if getIsBlack(rb(workingSibling.left())), getIsBlack(rb(workingSibling.right())) {
                    workingSibling.setRed()
                    redBlackNode = parent
                    redBlackNodeParent = redBlackNode?.parent()
                    isLeftChild = redBlackNodeParent.map { redBlackNodesIdentical(redBlackNode, rb($0.left())) } ?? false
                } else {
                    if getIsBlack(rb(workingSibling.left())) {
                        rb(workingSibling.right())?.setBlack()
                        workingSibling.setRed()
                        leftRotate(workingSibling)
                        guard let newSibling = rb(parent.left()) else { break }
                        workingSibling = newSibling
                    }
                    workingSibling.setIsBlack(parent.isBlack())
                    parent.setBlack()
                    rb(workingSibling.left())?.setBlack()
                    rightRotate(parent)
                    redBlackNode = rb(root())
                    redBlackNodeParent = nil
                }
            }
        }
        redBlackNode?.setBlack()
    }

    public func removeRecurse(
        _ redBlackNode: (any RedBlackNode)?,
        _ redBlackNode2: any RedBlackNode,
        _ t: T?
    ) {
        guard let redBlackNode else { return }
        let comparison = redBlackNode2.compareTo(redBlackNode)
        if comparison < 0 {
            removeRecurse(rb(redBlackNode.left()), redBlackNode2, t)
            updateNode(redBlackNode)
            return
        }
        if comparison > 0 {
            removeRecurse(rb(redBlackNode.right()), redBlackNode2, t)
            updateNode(redBlackNode)
            return
        }
        var performDeletion = true
        if let t {
            performDeletion = !removeInNested(redBlackNode, t)
        }
        if performDeletion {
            var wasBlack = redBlackNode.isBlack()
            var replacement: (any RedBlackNode)?
            var replacementParent: (any RedBlackNode)? = redBlackNode.parent()
            var replacementIsLeft = replacementParent.map { redBlackNodesIdentical(redBlackNode, rb($0.left())) } ?? false
            if redBlackNode.left() == nil {
                replacement = rb(redBlackNode.right())
                transplantSubTree(redBlackNode, rb(redBlackNode.right()))
            } else if redBlackNode.right() == nil {
                replacement = rb(redBlackNode.left())
                transplantSubTree(redBlackNode, rb(redBlackNode.left()))
            } else {
                guard let minNode = getMinNode(redBlackNode.right()) as? any RedBlackNode else { return }
                wasBlack = minNode.isBlack()
                replacement = rb(minNode.right())
                if redBlackNodesIdentical(minNode.parent(), redBlackNode) {
                    replacementParent = minNode
                    replacementIsLeft = false
                } else {
                    replacementParent = minNode.parent()
                    replacementIsLeft = minNode.parent().map { redBlackNodesIdentical(minNode, rb($0.left())) } ?? false
                    transplantSubTree(minNode, rb(minNode.right()))
                    var p = minNode.parent()
                    while let current = p, !redBlackNodesIdentical(current, redBlackNode) {
                        updateNode(current)
                        p = current.parent()
                    }
                    minNode.setRight(redBlackNode.right())
                    rb(minNode.right())?.setParent(minNode)
                }
                transplantSubTree(redBlackNode, minNode)
                minNode.setLeft(redBlackNode.left())
                rb(minNode.left())?.setParent(minNode)
                minNode.setIsBlack(redBlackNode.isBlack())
                updateNode(minNode)
            }
            if wasBlack {
                fixAfterDeletion(replacement, replacementParent, replacementIsLeft)
            }
        }
    }

    public override func remove(_ t: T) {
        guard let node = newNode(t) as? any RedBlackNode else {
            fatalError("RedBlackNestedTree.newNode must return a RedBlackNode")
        }
        removeRecurse(rb(root()), node, t)
    }

    // MARK: - Validation

    public func hasViolationRecurse(_ redBlackNode: (any RedBlackNode)?) -> Int {
        guard let redBlackNode else { return 1 }
        if redBlackNode.isRed(), getIsRed(rb(redBlackNode.left())) || getIsRed(rb(redBlackNode.right())) {
            return 0
        }
        if let left = rb(redBlackNode.left()), left.compareTo(redBlackNode) > 0 {
            return 0
        }
        if let right = rb(redBlackNode.right()), right.compareTo(redBlackNode) < 0 {
            return 0
        }
        let left = hasViolationRecurse(rb(redBlackNode.left()))
        let right = hasViolationRecurse(rb(redBlackNode.right()))
        if left == 0 || right == 0 { return 0 }
        if left == right {
            return redBlackNode.isRed() ? left : left + 1
        }
        return 0
    }

    public func hasViolation() -> Bool {
        hasViolationRecurse(rb(root())) == 0
    }
}
