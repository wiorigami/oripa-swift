// Port of `com.origamitoolbox.oripa.model.creasepattern.point.RedBlackPointTree`
// (oripa-port src/js/core/model/creasepattern/point/RedBlackPointTree.js).
//
// Two-level red-black tree indexing crease-pattern vertices: outer tree keyed on the point
// x key, each outer node is itself the nested tree keyed on the point y key.
import Foundation

// MARK: - Node protocol shared by outer x-nodes and inner y-nodes

protocol RedBlackPointNodeProtocol: RedBlackNode {
    func key() -> Int
    func value() -> Double
}

// MARK: - Abstract point tree

open class AbstractRedBlackPointTree: RedBlackNestedTree<OriPoint> {
    public override init() {
        super.init()
    }

    func pointNode(_ binaryNode: (any BinaryNode)?) -> (any RedBlackPointNodeProtocol)? {
        binaryNode as? any RedBlackPointNodeProtocol
    }

    open override func findAllInRangeRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<OriPoint> {
        let hashSet = JavaSet<OriPoint>()
        guard let binaryNode, let node = pointNode(binaryNode) else { return hashSet }
        if i > node.key() {
            return findAllInRangeRecurse(node.right(), i, i2, pointDouble, pointDouble2)
        }
        if i2 < node.key() {
            return findAllInRangeRecurse(node.left(), i, i2, pointDouble, pointDouble2)
        }
        hashSet.addAll(findAllInRangeNested(binaryNode, pointDouble, pointDouble2).values())
        hashSet.addAll(findAllInRangeRecurse(node.left(), i, i2, pointDouble, pointDouble2).values())
        hashSet.addAll(findAllInRangeRecurse(node.right(), i, i2, pointDouble, pointDouble2).values())
        return hashSet
    }

    open override func findNearestRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriPoint> {
        guard let binaryNode, let node = pointNode(binaryNode) else {
            return NearestItem<OriPoint>()
        }
        if i > node.key() {
            return findNearestRecurse(node.right(), i, i2, pointDouble, d)
        }
        if i2 < node.key() {
            return findNearestRecurse(node.left(), i, i2, pointDouble, d)
        }
        return compareNearest(
            findNearestInNested(binaryNode, pointDouble, d),
            compareNearest(
                findNearestRecurse(node.left(), i, i2, pointDouble, d),
                findNearestRecurse(node.right(), i, i2, pointDouble, d)
            )
        )
    }

    public func getMaxValueInTree() -> Double {
        guard let node = pointNode(getMaxNode(root())) else { return -Double.greatestFiniteMagnitude }
        return node.value()
    }

    public func getMinValueInTree() -> Double {
        guard let node = pointNode(getMinNode(root())) else { return Double.greatestFiniteMagnitude }
        return node.value()
    }

    open override func updateNode(_ binaryNode: any BinaryNode) {
        // Empty in the Java source (red-black bookkeeping only).
    }
}

// MARK: - Inner y-node

final class RedBlackPointYNode: RedBlackNodeBase, RedBlackPointNodeProtocol {
    let point: OriPoint

    init(_ oriPoint: OriPoint) {
        self.point = oriPoint
        super.init()
    }

    func key() -> Int { point.yKey }
    func value() -> Double { point.y }

    override func compareTo(_ other: any BinaryNode) -> Int {
        guard let binaryNode = other as? any RedBlackPointNodeProtocol else { return 0 }
        return (key() - binaryNode.key()).signum()
    }
}

// MARK: - Outer node that is also the nested y-tree

final class RedBlackPointXNode: AbstractRedBlackPointTree, RedBlackPointNodeProtocol {
    private var _isBlackNode: Bool = false
    private var _parentNode: (any RedBlackNode)?
    private var _leftNode: (any BinaryNode)?
    private var _rightNode: (any BinaryNode)?

    init(_ oriPoint: OriPoint) {
        super.init()
        insert(oriPoint)
    }

    // MARK: node protocol

    func key() -> Int {
        (root() as? RedBlackPointYNode)?.point.xKey ?? 0
    }

    func value() -> Double {
        (root() as? RedBlackPointYNode)?.point.x ?? 0
    }

    func isBlack() -> Bool { _isBlackNode }
    func isRed() -> Bool { !_isBlackNode }
    func setBlack() { _isBlackNode = true }
    func setRed() { _isBlackNode = false }
    func setIsBlack(_ value: Bool) { _isBlackNode = value }

    func parent() -> (any RedBlackNode)? { _parentNode }
    func setParent(_ node: (any RedBlackNode)?) { _parentNode = node }

    func left() -> (any BinaryNode)? { _leftNode }
    func right() -> (any BinaryNode)? { _rightNode }
    func setLeft(_ node: (any BinaryNode)?) { _leftNode = node }
    func setRight(_ node: (any BinaryNode)?) { _rightNode = node }

    func compareTo(_ other: any BinaryNode) -> Int {
        guard let binaryNode = other as? any RedBlackPointNodeProtocol else { return 0 }
        return (key() - binaryNode.key()).signum()
    }

    // MARK: nested y-tree hooks

    override func newNode(_ t: OriPoint) -> (any BinaryNode) {
        RedBlackPointYNode(t)
    }

    override func findAllInRange(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> JavaSet<OriPoint> {
        let key = OriPoint.getKey(pointDouble.y)
        let key2 = OriPoint.getKey(pointDouble2.y)
        return findAllInRangeRecurse(
            root(), key <= key2 ? key : key2, key <= key2 ? key2 : key, pointDouble, pointDouble2
        )
    }

    override func findAllInRangeNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<OriPoint> {
        let set = JavaSet<OriPoint>()
        if let node = binaryNode as? RedBlackPointYNode {
            set.add(node.point)
        }
        return set
    }

    override func findExactInNested(_ binaryNode: any BinaryNode, _ t: OriPoint) -> OriPoint? {
        guard let node = binaryNode as? RedBlackPointYNode else { return nil }
        return node.point
    }

    override func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriPoint> {
        guard let node = binaryNode as? RedBlackPointYNode else { return NearestItem<OriPoint>() }
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

// MARK: - Outer tree

final class RedBlackPointXTree: AbstractRedBlackPointTree {
    override func newNode(_ t: OriPoint) -> (any BinaryNode) {
        RedBlackPointXNode(t)
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
        guard let node = binaryNode as? RedBlackPointXNode else { return JavaSet<OriPoint>() }
        return node.findAllInRange(pointDouble, pointDouble2)
    }

    override func findExactInNested(_ binaryNode: any BinaryNode, _ t: OriPoint) -> OriPoint? {
        guard let node = binaryNode as? RedBlackPointXNode else { return nil }
        return node.findExact(t)
    }

    override func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriPoint> {
        guard let node = binaryNode as? RedBlackPointXNode else { return NearestItem<OriPoint>() }
        return node.findNearestInRange(pointDouble, d)
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
        guard let node = binaryNode as? RedBlackPointXNode else { return }
        node.insert(t)
    }

    override func removeInNested(_ binaryNode: any BinaryNode, _ t: OriPoint) -> Bool {
        guard let node = binaryNode as? RedBlackPointXNode else { return false }
        node.remove(t)
        return !node.isEmpty()
    }
}

// MARK: - Facade

public final class RedBlackPointTree {
    private let pointTree = RedBlackPointXTree()
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
        if pointMap.containsKey(oriPoint) {
            pointMap.remove(oriPoint)
            pointTree.remove(oriPoint)
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
            guard let pointXNode = iterator.next() as? RedBlackPointXNode else { continue }
            dMin = Swift.min(dMin, pointXNode.getMinValueInTree())
            dMax = Swift.max(dMax, pointXNode.getMaxValueInTree())
        }
        return MinMaxDouble(minValueInTree, dMin, maxValueInTree, dMax)
    }

    public func isEmpty() -> Bool {
        pointMap.isEmpty()
    }

    public func iterator() -> JavaIterator<OriPoint> {
        JavaIterator(pointMap.values())
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

    /// All points in reference-map iteration order (convenience used by the model/UI).
    public func getAllPoints() -> [OriPoint] {
        pointMap.values()
    }

    public func toString() -> String {
        var sb = "RedBlackPointTree("
        var iterator = iterator()
        while iterator.hasNext() {
            sb += "\(iterator.next()), "
        }
        return sb + ")"
    }
}

extension RedBlackPointTree: Sequence {
    public func makeIterator() -> AnyIterator<OriPoint> {
        var values = pointMap.values()
        var index = 0
        return AnyIterator {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }
}
