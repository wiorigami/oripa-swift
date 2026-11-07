// Port of `com.origamitoolbox.oripa.model.creasepattern.line.AvlLineTree`
// (oripa-port src/js/core/model/creasepattern/line/AvlLineTree.js).
//
// Two-level AVL tree: outer tree keyed on the line x-interval, each outer node carries a
// nested AVL tree keyed on the y-interval. `CreasePattern` uses the red-black variant; this
// AVL variant is part of the Java/JS model contract (and covered by the reference tests).
import Foundation

class AvlLineNode: AvlNode {
    func high() -> Int { fatalError("abstract: AvlLineNode.high") }
    func low() -> Int { fatalError("abstract: AvlLineNode.low") }
    func max() -> Int { fatalError("abstract: AvlLineNode.max") }
    func setMax(_ value: Int) { fatalError("abstract: AvlLineNode.setMax") }
}

final class AvlLineYNode: AvlLineNode {
    let line: OriLine
    private var _subtreeMax: Int
    private var _leftNode: (any BinaryNode)?
    private var _rightNode: (any BinaryNode)?

    public init(_ oriLine: OriLine) {
        self.line = oriLine
        self._subtreeMax = 0
        super.init()
        self._subtreeMax = high()
    }

    override func low() -> Int { Swift.min(line.start.yKey, line.end.yKey) }
    override func high() -> Int { Swift.max(line.start.yKey, line.end.yKey) }
    override func max() -> Int { _subtreeMax }
    override func setMax(_ value: Int) { _subtreeMax = value }

    override func left() -> (any BinaryNode)? { _leftNode }
    override func right() -> (any BinaryNode)? { _rightNode }
    override func setLeft(_ node: (any BinaryNode)?) { _leftNode = node }
    override func setRight(_ node: (any BinaryNode)?) { _rightNode = node }

    override func compareTo(_ other: any BinaryNode) -> Int {
        guard let binaryNode = other as? AvlLineNode else { return 0 }
        if low() == binaryNode.low() {
            return (high() - binaryNode.high()).signum()
        }
        return (low() - binaryNode.low()).signum()
    }
}

final class AvlLineXNode: AvlLineNode {
    let yTree: AvlLineYTree
    private var _low: Int
    private var _high: Int
    private var _subtreeMax: Int
    private var _leftNode: (any BinaryNode)?
    private var _rightNode: (any BinaryNode)?

    public init(_ oriLine: OriLine) {
        self.yTree = AvlLineYTree(oriLine)
        self._low = oriLine.start.xKey
        self._high = oriLine.end.xKey
        self._subtreeMax = oriLine.end.xKey
        super.init()
    }

    override func low() -> Int { _low }
    override func high() -> Int { _high }
    override func max() -> Int { _subtreeMax }
    override func setMax(_ value: Int) { _subtreeMax = value }

    override func left() -> (any BinaryNode)? { _leftNode }
    override func right() -> (any BinaryNode)? { _rightNode }
    override func setLeft(_ node: (any BinaryNode)?) { _leftNode = node }
    override func setRight(_ node: (any BinaryNode)?) { _rightNode = node }

    override func compareTo(_ other: any BinaryNode) -> Int {
        guard let binaryNode = other as? AvlLineXNode else { return 0 }
        if low() == binaryNode.low() {
            return (high() - binaryNode.high()).signum()
        }
        return (low() - binaryNode.low()).signum()
    }
}

open class AbstractAvlLineTree: AvlNestedTree<OriLine> {
    public override init() {
        super.init()
    }

    func doIntervalsOverlap(_ i: Int, _ i2: Int, _ i3: Int, _ i4: Int) -> Bool {
        i <= i4 && i3 <= i2
    }

    func getMaxRange(_ avlNode: AvlNode?) -> Int {
        guard let avlNode = avlNode as? AvlLineNode else { return Int(Int32.min) }
        return avlNode.max()
    }

    func updateMax(_ avlNode: AvlNode?) {
        guard let avlNode = avlNode as? AvlLineNode else { return }
        let maxRange = Swift.max(getMaxRange(avlNode.left() as? AvlNode), getMaxRange(avlNode.right() as? AvlNode))
        avlNode.setMax(Swift.max(avlNode.high(), maxRange))
    }

    open override func updateNode(_ binaryNode: any BinaryNode) {
        super.updateNode(binaryNode)
        updateMax(binaryNode as? AvlNode)
    }

    open override func findAllInRangeRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<OriLine> {
        let hashSet = JavaSet<OriLine>()
        guard let binaryNode, let avlNode = binaryNode as? AvlLineNode else { return hashSet }
        if i > avlNode.max() {
            return hashSet
        }
        if doIntervalsOverlap(i, i2, avlNode.low(), avlNode.high()) {
            hashSet.addAll(findAllInRangeNested(binaryNode, pointDouble, pointDouble2).values())
        }
        hashSet.addAll(findAllInRangeRecurse(avlNode.left(), i, i2, pointDouble, pointDouble2).values())
        if i2 < avlNode.low() {
            return hashSet
        }
        hashSet.addAll(findAllInRangeRecurse(avlNode.right(), i, i2, pointDouble, pointDouble2).values())
        return hashSet
    }

    open override func findNearestRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriLine> {
        guard let binaryNode, let avlNode = binaryNode as? AvlLineNode else {
            return NearestItem<OriLine>()
        }
        var nearestItem = NearestItem<OriLine>()
        if i > avlNode.max() {
            return nearestItem
        }
        if doIntervalsOverlap(i, i2, avlNode.low(), avlNode.high()) {
            nearestItem = compareNearest(nearestItem, findNearestInNested(binaryNode, pointDouble, d))
        }
        let leftNearest = compareNearest(nearestItem, findNearestRecurse(avlNode.left(), i, i2, pointDouble, d))
        if i2 < avlNode.low() {
            return leftNearest
        }
        return compareNearest(leftNearest, findNearestRecurse(avlNode.right(), i, i2, pointDouble, d))
    }
}

final class AvlLineYTree: AbstractAvlLineTree {
    public init(_ oriLine: OriLine) {
        super.init()
        insert(oriLine)
    }

    override func newNode(_ t: OriLine) -> (any BinaryNode) {
        AvlLineYNode(t)
    }

    override func findAllInRange(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> JavaSet<OriLine> {
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
    ) -> JavaSet<OriLine> {
        let set = JavaSet<OriLine>()
        if let node = binaryNode as? AvlLineYNode {
            set.add(node.line)
        }
        return set
    }

    override func findExactInNested(_ binaryNode: any BinaryNode, _ t: OriLine) -> OriLine? {
        guard let node = binaryNode as? AvlLineYNode else { return nil }
        return t.equals(node.line) ? node.line : nil
    }

    override func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriLine> {
        guard let node = binaryNode as? AvlLineYNode else { return NearestItem<OriLine>() }
        return NearestItem(node.line, node.line.getMinDistance(pointDouble))
    }

    override func findNearestInRange(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriLine> {
        findNearestRecurse(
            root(),
            OriPoint.getKey(pointDouble.y - d),
            OriPoint.getKey(pointDouble.y + d),
            pointDouble,
            d
        )
    }

    override func insertIntoNested(_ binaryNode: any BinaryNode, _ t: OriLine) {
        fatalError("Should not be reinserting object")
    }

    override func removeInNested(_ binaryNode: any BinaryNode, _ t: OriLine) -> Bool {
        false
    }
}

final class AvlLineXTree: AbstractAvlLineTree {
    override func newNode(_ t: OriLine) -> (any BinaryNode) {
        AvlLineXNode(t)
    }

    override func findAllInRange(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> JavaSet<OriLine> {
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
    ) -> JavaSet<OriLine> {
        guard let node = binaryNode as? AvlLineXNode else { return JavaSet<OriLine>() }
        return node.yTree.findAllInRange(pointDouble, pointDouble2)
    }

    override func findExactInNested(_ binaryNode: any BinaryNode, _ t: OriLine) -> OriLine? {
        guard let node = binaryNode as? AvlLineXNode else { return nil }
        return node.yTree.findExact(t)
    }

    override func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriLine> {
        guard let node = binaryNode as? AvlLineXNode else { return NearestItem<OriLine>() }
        return node.yTree.findNearestInRange(pointDouble, d)
    }

    override func findNearestInRange(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriLine> {
        findNearestRecurse(
            root(),
            OriPoint.getKey(pointDouble.x - d),
            OriPoint.getKey(pointDouble.x + d),
            pointDouble,
            d
        )
    }

    override func insertIntoNested(_ binaryNode: any BinaryNode, _ t: OriLine) {
        guard let node = binaryNode as? AvlLineXNode else { return }
        node.yTree.insert(t)
    }

    override func removeInNested(_ binaryNode: any BinaryNode, _ t: OriLine) -> Bool {
        guard let node = binaryNode as? AvlLineXNode else { return false }
        node.yTree.remove(t)
        return !node.yTree.isEmpty()
    }

    func toString() -> String {
        var sb = "LineXTree("
        let it = iterator()
        while it.hasNext() {
            sb += "\(it.next()), "
        }
        return sb + ")"
    }
}

/// In-order walk over the nested (x, then y) trees.
public final class AvlLineIterator {
    private let iteratorX: BinaryIterator
    private var iteratorY: BinaryIterator?

    init(_ lineXTree: AvlLineXTree) {
        iteratorX = lineXTree.iterator()
        if iteratorX.hasNext(), let node = iteratorX.next() as? AvlLineXNode {
            iteratorY = node.yTree.iterator()
        }
    }

    public func hasNext() -> Bool {
        iteratorY?.hasNext() ?? false
    }

    public func next() -> OriLine {
        guard let iteratorY, let node = iteratorY.next() as? AvlLineYNode else {
            fatalError("AvlLineIterator exhausted")
        }
        if !iteratorY.hasNext(), iteratorX.hasNext(), let nextNode = iteratorX.next() as? AvlLineXNode {
            self.iteratorY = nextNode.yTree.iterator()
        }
        return node.line
    }
}

// MARK: - Facade

public final class AvlLineTree {
    private let lineTree = AvlLineXTree()
    private let lineMap = JavaMap<OriLine, OriLine>()

    public init() {}

    public func addLine(_ oriLine: OriLine) {
        if lineMap.containsKey(oriLine) {
            return
        }
        lineMap.put(oriLine, oriLine)
        lineTree.insert(oriLine)
    }

    public func clear() {
        lineTree.clear()
        lineMap.clear()
    }

    public func contains(_ oriLine: OriLine) -> Bool {
        lineMap.containsKey(oriLine)
    }

    public func findAllLinesInRange(_ pointDouble: PointDouble, _ pointDouble2: PointDouble) -> JavaSet<OriLine> {
        lineTree.findAllInRange(
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

    public func findLine(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriLine> {
        let nearestItem = lineTree.findNearestInRange(pointDouble, d)
        return nearestItem.distance <= d ? nearestItem : NearestItem<OriLine>()
    }

    public func getAllLines() -> JavaSet<OriLine> {
        let set = JavaSet<OriLine>()
        set.addAll(lineMap.values())
        return set
    }

    public func isEmpty() -> Bool {
        lineMap.isEmpty()
    }

    public func iterator() -> AvlLineIterator {
        AvlLineIterator(lineTree)
    }

    public func removeLine(_ oriLine: OriLine) {
        if let stored = lineMap.remove(oriLine) {
            lineTree.remove(stored)
        }
    }

    public func size() -> Int {
        lineMap.size()
    }

    public func toString() -> String {
        var sb = "AvlLineTree("
        let it = iterator()
        while it.hasNext() {
            sb += "\(it.next()), "
        }
        return sb + ")"
    }
}

extension AvlLineTree: Sequence {
    public func makeIterator() -> AnyIterator<OriLine> {
        let iterator = self.iterator()
        return AnyIterator {
            iterator.hasNext() ? iterator.next() : nil
        }
    }
}
