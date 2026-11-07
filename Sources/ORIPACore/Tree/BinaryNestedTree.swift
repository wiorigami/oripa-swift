// Port of `com.origamitoolbox.oripa.tree.BinaryNestedTree<T>`
// (oripa-port src/js/core/tree/BinaryNestedTree.js).
//
// A binary tree whose nodes carry a nested collection of values `T` (the "nested" in the
// name). Concrete AVL/red-black subclasses implement the balancing and storage hooks.
import Foundation

open class BinaryNestedTree<T: AnyObject>: BinaryTree {
    public override init() {
        super.init()
    }

    // MARK: - Abstract hooks (implemented by concrete nested trees)

    open func newNode(_ t: T) -> (any BinaryNode) {
        fatalError("abstract: BinaryNestedTree.newNode")
    }

    open func insertIntoNested(_ binaryNode: any BinaryNode, _ t: T) {
        fatalError("abstract: BinaryNestedTree.insertIntoNested")
    }

    open func removeInNested(_ binaryNode: any BinaryNode, _ t: T) -> Bool {
        fatalError("abstract: BinaryNestedTree.removeInNested")
    }

    open func findExactInNested(_ binaryNode: any BinaryNode, _ t: T) -> T? {
        fatalError("abstract: BinaryNestedTree.findExactInNested")
    }

    open func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<T> {
        fatalError("abstract: BinaryNestedTree.findNearestInNested")
    }

    open func findAllInRangeNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<T> {
        fatalError("abstract: BinaryNestedTree.findAllInRangeNested")
    }

    open func findAllInRange(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> JavaSet<T> {
        fatalError("abstract: BinaryNestedTree.findAllInRange")
    }

    open func findAllInRangeRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<T> {
        fatalError("abstract: BinaryNestedTree.findAllInRangeRecurse")
    }

    open func findNearestInRange(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<T> {
        fatalError("abstract: BinaryNestedTree.findNearestInRange")
    }

    open func findNearestRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<T> {
        fatalError("abstract: BinaryNestedTree.findNearestRecurse")
    }

    open func insert(_ t: T) {
        fatalError("abstract: BinaryNestedTree.insert")
    }

    open func remove(_ t: T) {
        fatalError("abstract: BinaryNestedTree.remove")
    }

    // MARK: - Shared implementation

    public func compareNearest(_ nearestItem: NearestItem<T>, _ nearestItem2: NearestItem<T>) -> NearestItem<T> {
        nearestItem.distance > nearestItem2.distance ? nearestItem2 : nearestItem
    }

    public func findExact(_ t: T) -> T? {
        findExactRecurse(root(), newNode(t), t)
    }

    public func findExactRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ binaryNode2: (any BinaryNode)?,
        _ t: T
    ) -> T? {
        guard let binaryNode, let binaryNode2 else { return nil }
        let comparison = binaryNode2.compareTo(binaryNode)
        if comparison < 0 {
            return findExactRecurse(binaryNode.left(), binaryNode2, t)
        }
        if comparison > 0 {
            return findExactRecurse(binaryNode.right(), binaryNode2, t)
        }
        return findExactInNested(binaryNode, t)
    }
}
