// Port of `com.origamitoolbox.oripa.model.creasepattern.point.AvlPointTree`
// (oripa-port src/js/core/model/creasepattern/point/AvlPointTree.js).
//
// Two-level AVL tree: outer tree keyed on the point x key, each outer node carries a nested
// AVL tree keyed on the point y key. `CreasePattern` uses the red-black variant; this AVL
// variant is part of the Java/JS model contract (and covered by the reference tests).
import Foundation

class AvlPointNode: AvlNode {
    func key() -> Int { fatalError("abstract: AvlPointNode.key") }
    func value() -> Double { fatalError("abstract: AvlPointNode.value") }
}

final class AvlPointYNode: AvlPointNode {
    let point: OriPoint
    private var _leftNode: (any BinaryNode)?
    private var _rightNode: (any BinaryNode)?

    public init(_ oriPoint: OriPoint) {
        self.point = oriPoint
        super.init()
    }

    override func key() -> Int { point.yKey }
    override func value() -> Double { point.y }

    override func left() -> (any BinaryNode)? { _leftNode }
    override func right() -> (any BinaryNode)? { _rightNode }
    override func setLeft(_ node: (any BinaryNode)?) { _leftNode = node }
    override func setRight(_ node: (any BinaryNode)?) { _rightNode = node }

    override func compareTo(_ other: any BinaryNode) -> Int {
        guard let binaryNode = other as? AvlPointNode else { return 0 }
        return (key() - binaryNode.key()).signum()
    }
}

final class AvlPointXNode: AvlPointNode {
    let yTree: AvlPointYTree
    private var _keyValue: Int
    private var _valueValue: Double
    private var _leftNode: (any BinaryNode)?
    private var _rightNode: (any BinaryNode)?

    public init(_ oriPoint: OriPoint) {
        self.yTree = AvlPointYTree(oriPoint)
        self._keyValue = oriPoint.xKey
        self._valueValue = oriPoint.x
        super.init()
    }

    override func key() -> Int { _keyValue }
    override func value() -> Double { _valueValue }

    override func left() -> (any BinaryNode)? { _leftNode }
    override func right() -> (any BinaryNode)? { _rightNode }
    override func setLeft(_ node: (any BinaryNode)?) { _leftNode = node }
    override func setRight(_ node: (any BinaryNode)?) { _rightNode = node }

    override func compareTo(_ other: any BinaryNode) -> Int {
        guard let binaryNode = other as? AvlPointNode else { return 0 }
        return (key() - binaryNode.key()).signum()
    }
}

open class AbstractAvlPointTree: AvlNestedTree<OriPoint> {
    public override init() {
        super.init()
    }

    open override func findAllInRangeRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<OriPoint> {
        let hashSet = JavaSet<OriPoint>()
        guard let binaryNode, let avlNode = binaryNode as? AvlPointNode else { return hashSet }
        if i > avlNode.key() {
            return findAllInRangeRecurse(avlNode.right(), i, i2, pointDouble, pointDouble2)
        }
        if i2 < avlNode.key() {
            return findAllInRangeRecurse(avlNode.left(), i, i2, pointDouble, pointDouble2)
        }
        hashSet.addAll(findAllInRangeNested(binaryNode, pointDouble, pointDouble2).values())
        hashSet.addAll(findAllInRangeRecurse(avlNode.left(), i, i2, pointDouble, pointDouble2).values())
        hashSet.addAll(findAllInRangeRecurse(avlNode.right(), i, i2, pointDouble, pointDouble2).values())
        return hashSet
    }

    open override func findNearestRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriPoint> {
        guard let binaryNode, let avlNode = binaryNode as? AvlPointNode else {
            return NearestItem<OriPoint>()
        }
        if i > avlNode.key() {
            return findNearestRecurse(avlNode.right(), i, i2, pointDouble, d)
        }
        if i2 < avlNode.key() {
            return findNearestRecurse(avlNode.left(), i, i2, pointDouble, d)
        }
        return compareNearest(
            findNearestInNested(binaryNode, pointDouble, d),
            compareNearest(
                findNearestRecurse(avlNode.left(), i, i2, pointDouble, d),
                findNearestRecurse(avlNode.right(), i, i2, pointDouble, d)
            )
        )
    }

    func getMaxValueInTree() -> Double {
        guard let avlNode = getMaxNode(root()) as? AvlPointNode else { return -Double.greatestFiniteMagnitude }
        return avlNode.value()
    }

    func getMinValueInTree() -> Double {
        guard let avlNode = getMinNode(root()) as? AvlPointNode else { return Double.greatestFiniteMagnitude }
        return avlNode.value()
    }
}

final class AvlPointYTree: AbstractAvlPointTree {
    public init(_ oriPoint: OriPoint) {
        super.init()
        insert(oriPoint)
    }

    override func newNode(_ t: OriPoint) -> (any BinaryNode) {
        AvlPointYNode(t)
    }

    override func findAllInRange(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> JavaSet<OriPoint> {
        findAllInRangeRecurse(
            root(),
            OriPoint.getKey(pointDouble.y),
            OriPoint.getKey(pointDouble2.y),
            pointDouble,
            pointDouble2
        )
    }

    override func findAllInRangeNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<OriPoint> {
        let set = JavaSet<OriPoint>()
        if let node = binaryNode as? AvlPointYNode {
            set.add(node.point)
        }
        return set
    }

    override func findExactInNested(_ binaryNode: any BinaryNode, _ t: OriPoint) -> OriPoint? {
        (binaryNode as? AvlPointYNode)?.point
    }

    override func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriPoint> {
        guard let node = binaryNode as? AvlPointYNode else { return NearestItem<OriPoint>() }
        return NearestItem(node.point, node.point.getMinDistance(pointDouble))
    }

    override func findNearestInRange(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriPoint> {
        findNearestRecurse(
            root(),
            OriPoint.getKey(pointDouble.y - d),
            OriPoint.getKey(pointDouble.y + d),
            pointDouble,
            d
        )
    }

    override func insertIntoNested(_ binaryNode: any BinaryNode, _ t: OriPoint) {
        fatalError("Should not be reinserting object")
    }

    override func removeInNested(_ binaryNode: any BinaryNode, _ t: OriPoint) -> Bool {
        false
    }
}

final class AvlPointXTree: AbstractAvlPointTree {
    override func newNode(_ t: OriPoint) -> (any BinaryNode) {
        AvlPointXNode(t)
    }

    override func findAllInRange(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> JavaSet<OriPoint> {
        findAllInRangeRecurse(
            root(),
            OriPoint.getKey(pointDouble.x),
            OriPoint.getKey(pointDouble2.x),
            pointDouble,
            pointDouble2
        )
    }

    override func findAllInRangeNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<OriPoint> {
        guard let node = binaryNode as? AvlPointXNode else { return JavaSet<OriPoint>() }
        return node.yTree.findAllInRange(pointDouble, pointDouble2)
    }

    override func findExactInNested(_ binaryNode: any BinaryNode, _ t: OriPoint) -> OriPoint? {
        guard let node = binaryNode as? AvlPointXNode else { return nil }
        return node.yTree.findExact(t)
    }

    override func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriPoint> {
        guard let node = binaryNode as? AvlPointXNode else { return NearestItem<OriPoint>() }
        return node.yTree.findNearestInRange(pointDouble, d)
    }

    override func findNearestInRange(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriPoint> {
        findNearestRecurse(
            root(),
            OriPoint.getKey(pointDouble.x - d),
            OriPoint.getKey(pointDouble.x + d),
            pointDouble,
            d
        )
    }

    override func insertIntoNested(_ binaryNode: any BinaryNode, _ t: OriPoint) {
        guard let node = binaryNode as? AvlPointXNode else { return }
        node.yTree.insert(t)
    }

    override func removeInNested(_ binaryNode: any BinaryNode, _ t: OriPoint) -> Bool {
        guard let node = binaryNode as? AvlPointXNode else { return false }
        node.yTree.remove(t)
        return !node.yTree.isEmpty()
    }
}

/// In-order walk over the nested (x, then y) trees.
public final class AvlPointIterator {
    private let iteratorX: BinaryIterator
    private var iteratorY: BinaryIterator?

    init(_ pointXTree: AvlPointXTree) {
        iteratorX = pointXTree.iterator()
        if iteratorX.hasNext(), let node = iteratorX.next() as? AvlPointXNode {
            iteratorY = node.yTree.iterator()
        }
    }

    public func hasNext() -> Bool {
        iteratorY?.hasNext() ?? false
    }

    public func next() -> OriPoint {
        guard let iteratorY, let node = iteratorY.next() as? AvlPointYNode else {
            fatalError("AvlPointIterator exhausted")
        }
        if !iteratorY.hasNext(), iteratorX.hasNext(), let nextNode = iteratorX.next() as? AvlPointXNode {
            self.iteratorY = nextNode.yTree.iterator()
        }
        return node.point
    }
}

// MARK: - Facade

public final class AvlPointTree {
    private let pointTree = AvlPointXTree()
    private let pointMap = JavaMap<OriPoint, OriPoint>()

    public init() {}

    public func add(_ oriPoint: OriPoint) {
        if pointMap.containsKey(oriPoint) {
            return
        }
        pointMap.put(oriPoint, oriPoint)
        pointTree.insert(oriPoint)
    }

    public func remove(_ oriPoint: OriPoint) {
        if let stored = pointMap.remove(oriPoint) {
            pointTree.remove(stored)
        }
    }

    public func addLine(_ oriLine: OriLine) -> OriLine {
        var oriPoint = oriLine.start
        var oriPoint2 = oriLine.end
        if pointMap.containsKey(oriLine.start) {
            oriPoint = pointMap.get(oriLine.start)!
        } else {
            add(oriPoint)
        }
        if pointMap.containsKey(oriLine.end) {
            oriPoint2 = pointMap.get(oriLine.end)!
        } else {
            add(oriPoint2)
        }
        let oriLine2 = OriLine(oriPoint, oriPoint2, oriLine.type())
        oriPoint.addLine(oriLine2)
        oriPoint2.addLine(oriLine2)
        return oriLine2
    }

    public func clear() {
        pointTree.clear()
        pointMap.clear()
    }

    public func contains(_ oriPoint: OriPoint) -> Bool {
        pointMap.containsKey(oriPoint)
    }

    public func findAllPointsInRange(
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<OriPoint> {
        pointTree.findAllInRange(
            PointDouble(
                Swift.min(pointDouble.x, pointDouble2.x),
                Swift.min(pointDouble.y, pointDouble2.y)
            ),
            PointDouble(
                Swift.max(pointDouble.x, pointDouble2.x),
                Swift.max(pointDouble.y, pointDouble2.y)
            )
        )
    }

    public func findPoint(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriPoint> {
        let nearestItem = pointTree.findNearestInRange(pointDouble, d)
        return nearestItem.distance <= d ? nearestItem : NearestItem<OriPoint>()
    }

    public func getMinMax(_ d: Double) -> MinMaxDouble {
        if isEmpty() {
            let d2 = -d
            return MinMaxDouble(d2, d2, d, d)
        }
        let minValueInTree = pointTree.getMinValueInTree()
        let maxValueInTree = pointTree.getMaxValueInTree()
        var dMax = -Double.greatestFiniteMagnitude
        var dMin = Double.greatestFiniteMagnitude
        let iterator = pointTree.iterator()
        while iterator.hasNext() {
            guard let pointXNode = iterator.next() as? AvlPointXNode else { continue }
            dMin = Swift.min(dMin, pointXNode.yTree.getMinValueInTree())
            dMax = Swift.max(dMax, pointXNode.yTree.getMaxValueInTree())
        }
        return MinMaxDouble(minValueInTree, dMin, maxValueInTree, dMax)
    }

    public func isEmpty() -> Bool {
        pointMap.isEmpty()
    }

    public func iterator() -> AvlPointIterator {
        AvlPointIterator(pointTree)
    }

    public func removeLine(_ oriLine: OriLine) {
        guard let oriPoint = pointMap.get(oriLine.start),
              let oriPoint2 = pointMap.get(oriLine.end) else { return }
        oriPoint.removeLine(oriLine)
        oriPoint2.removeLine(oriLine)
        if oriPoint.getOccurrenceCount() == 0 {
            remove(oriPoint)
        }
        if oriPoint2.getOccurrenceCount() == 0 {
            remove(oriPoint2)
        }
    }

    public func size() -> Int {
        pointMap.size()
    }

    public func toString() -> String {
        var sb = "AvlPointTree("
        let it = iterator()
        while it.hasNext() {
            sb += "\(it.next()), "
        }
        return sb + ")"
    }
}

extension AvlPointTree: Sequence {
    public func makeIterator() -> AnyIterator<OriPoint> {
        let iterator = self.iterator()
        return AnyIterator {
            iterator.hasNext() ? iterator.next() : nil
        }
    }
}
