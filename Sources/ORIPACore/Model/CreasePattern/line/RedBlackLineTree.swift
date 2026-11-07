// Port of `com.origamitoolbox.oripa.model.creasepattern.line.RedBlackLineTree`
// (oripa-port src/js/core/model/creasepattern/line/RedBlackLineTree.js).
//
// A two-level red-black tree indexing crease lines: the outer tree is keyed on the line
// x-interval, each outer node is itself the nested tree keyed on the y-interval (this is
// why `LineXNodeYTree` is both a node and a tree).
import Foundation

// MARK: - Node protocol shared by the outer x-nodes and inner y-nodes

protocol RedBlackLineNodeProtocol: RedBlackNode {
    func low() -> Int
    func high() -> Int
    func max() -> Int
    func setMax(_ value: Int)
}

// MARK: - Abstract line tree (interval search)

open class AbstractRedBlackLineTree: RedBlackNestedTree<OriLine> {
    public override init() {
        super.init()
    }

    func doIntervalsOverlap(_ i: Int, _ i2: Int, _ i3: Int, _ i4: Int) -> Bool {
        i <= i4 && i3 <= i2
    }

    func lineNode(_ binaryNode: (any BinaryNode)?) -> (any RedBlackLineNodeProtocol)? {
        binaryNode as? any RedBlackLineNodeProtocol
    }

    func getMaxRange(_ binaryNode: (any BinaryNode)?) -> Int {
        guard let node = lineNode(binaryNode) else { return Int(Int32.min) }
        return node.max()
    }

    func updateMax(_ binaryNode: (any BinaryNode)?) {
        guard let node = lineNode(binaryNode) else { return }
        let maxRange = Swift.max(getMaxRange(node.left()), getMaxRange(node.right()))
        node.setMax(Swift.max(node.high(), maxRange))
    }

    open override func updateNode(_ binaryNode: any BinaryNode) {
        updateMax(binaryNode)
    }

    open override func findAllInRangeRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> JavaSet<OriLine> {
        let hashSet = JavaSet<OriLine>()
        guard let binaryNode, let node = lineNode(binaryNode) else { return hashSet }
        if i > node.max() {
            return hashSet
        }
        if doIntervalsOverlap(i, i2, node.low(), node.high()) {
            hashSet.addAll(findAllInRangeNested(binaryNode, pointDouble, pointDouble2).values())
        }
        hashSet.addAll(findAllInRangeRecurse(node.left(), i, i2, pointDouble, pointDouble2).values())
        if i2 < node.low() {
            return hashSet
        }
        hashSet.addAll(findAllInRangeRecurse(node.right(), i, i2, pointDouble, pointDouble2).values())
        return hashSet
    }

    open override func findNearestRecurse(
        _ binaryNode: (any BinaryNode)?,
        _ i: Int,
        _ i2: Int,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriLine> {
        guard let binaryNode, let node = lineNode(binaryNode) else {
            return NearestItem<OriLine>()
        }
        var nearestItem = NearestItem<OriLine>()
        if i > node.max() {
            return nearestItem
        }
        if doIntervalsOverlap(i, i2, node.low(), node.high()) {
            nearestItem = compareNearest(nearestItem, findNearestInNested(binaryNode, pointDouble, d))
        }
        let leftNearest = compareNearest(nearestItem, findNearestRecurse(node.left(), i, i2, pointDouble, d))
        if i2 < node.low() {
            return leftNearest
        }
        return compareNearest(leftNearest, findNearestRecurse(node.right(), i, i2, pointDouble, d))
    }
}

// MARK: - Inner y-node

final class RedBlackLineYNode: RedBlackNodeBase, RedBlackLineNodeProtocol {
    let line: OriLine
    private var _subtreeMax: Int

    init(_ oriLine: OriLine) {
        self.line = oriLine
        self._subtreeMax = 0
        super.init()
        self._subtreeMax = high()
    }

    func low() -> Int { Swift.min(line.start.yKey, line.end.yKey) }

    func high() -> Int { Swift.max(line.start.yKey, line.end.yKey) }

    func max() -> Int { _subtreeMax }

    func setMax(_ value: Int) { _subtreeMax = value }

    override func compareTo(_ other: any BinaryNode) -> Int {
        guard let binaryNode = other as? any RedBlackLineNodeProtocol else { return 0 }
        if low() == binaryNode.low() {
            return (high() - binaryNode.high()).signum()
        }
        return (low() - binaryNode.low()).signum()
    }
}

// MARK: - Outer node that is also the nested y-tree

final class RedBlackLineXNode: AbstractRedBlackLineTree, RedBlackLineNodeProtocol {
    private var _subtreeMax: Int = 0
    private var _isBlackNode: Bool = false
    private var _parentNode: (any RedBlackNode)?
    private var _leftNode: (any BinaryNode)?
    private var _rightNode: (any BinaryNode)?

    init(_ oriLine: OriLine) {
        super.init()
        insert(oriLine)
        setMax(high())
    }

    // MARK: node protocol

    func low() -> Int {
        (root() as? RedBlackLineYNode)?.line.start.xKey ?? 0
    }

    func high() -> Int {
        (root() as? RedBlackLineYNode)?.line.end.xKey ?? 0
    }

    func max() -> Int { _subtreeMax }

    func setMax(_ value: Int) { _subtreeMax = value }

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
        guard let binaryNode = other as? any RedBlackLineNodeProtocol else { return 0 }
        if low() == binaryNode.low() {
            return (high() - binaryNode.high()).signum()
        }
        return (low() - binaryNode.low()).signum()
    }

    // MARK: nested y-tree hooks

    override func newNode(_ t: OriLine) -> (any BinaryNode) {
        RedBlackLineYNode(t)
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
        if let node = binaryNode as? RedBlackLineYNode {
            set.add(node.line)
        }
        return set
    }

    override func findExactInNested(_ binaryNode: any BinaryNode, _ t: OriLine) -> OriLine? {
        guard let node = binaryNode as? RedBlackLineYNode else { return nil }
        return t.equals(node.line) ? node.line : nil
    }

    override func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriLine> {
        guard let node = binaryNode as? RedBlackLineYNode else { return NearestItem<OriLine>() }
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

    func printPreOrder() {
        printPreOrderRecurse(root())
    }

    private func printPreOrderRecurse(_ node: (any BinaryNode)?) {
        guard let node else { return }
        print(node)
        if let yNode = node as? RedBlackLineYNode {
            print(yNode.line)
        }
        printPreOrderRecurse(node.left())
        printPreOrderRecurse(node.right())
    }
}

// MARK: - Outer tree

final class RedBlackLineXTree: AbstractRedBlackLineTree {
    override func newNode(_ t: OriLine) -> (any BinaryNode) {
        RedBlackLineXNode(t)
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
        guard let node = binaryNode as? RedBlackLineXNode else { return JavaSet<OriLine>() }
        return node.findAllInRange(pointDouble, pointDouble2)
    }

    override func findExactInNested(_ binaryNode: any BinaryNode, _ t: OriLine) -> OriLine? {
        guard let node = binaryNode as? RedBlackLineXNode else { return nil }
        return node.findExact(t)
    }

    override func findNearestInNested(
        _ binaryNode: any BinaryNode,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> NearestItem<OriLine> {
        guard let node = binaryNode as? RedBlackLineXNode else { return NearestItem<OriLine>() }
        return node.findNearestInRange(pointDouble, d)
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
        guard let node = binaryNode as? RedBlackLineXNode else { return }
        node.insert(t)
    }

    override func removeInNested(_ binaryNode: any BinaryNode, _ t: OriLine) -> Bool {
        guard let node = binaryNode as? RedBlackLineXNode else { return false }
        node.remove(t)
        return !node.isEmpty()
    }

    func printPreOrder() {
        printPreOrderRecurse(root())
    }

    private func printPreOrderRecurse(_ node: (any BinaryNode)?) {
        guard let node else { return }
        print(node)
        if let xNode = node as? RedBlackLineXNode { xNode.printPreOrder() }
        printPreOrderRecurse(node.left())
        printPreOrderRecurse(node.right())
    }
}

// MARK: - Facade

public final class RedBlackLineTree {
    private let lineTree = RedBlackLineXTree()
    private let lineMap = JavaMap<OriLine, OriLine>()

    public init() {}

    /// JS `addLine`: returns true when the line was inserted (duplicates / diagonal
    /// duplicates are rejected, matching the reference).
    @discardableResult
    public func addLine(_ oriLine: OriLine) -> Bool {
        if lineMap.containsKey(oriLine) || lineMap.containsKey(oriLine.diagonalCopy()) {
            return false
        }
        lineMap.put(oriLine, oriLine)
        lineTree.insert(oriLine)
        return true
    }

    @discardableResult
    public func addLineNoCheck(_ oriLine: OriLine) -> OriLine {
        lineMap.put(oriLine, oriLine)
        lineTree.insert(oriLine)
        return oriLine
    }

    public func changeLineType(_ oriLine: OriLine, _ b: LineType) {
        lineMap.get(oriLine)?.setType(b)
    }

    public func clear() {
        lineTree.clear()
        lineMap.clear()
    }

    public func contains(_ oriLine: OriLine) -> Bool {
        lineMap.containsKey(oriLine)
    }

    public func removeLine(_ oriLine: OriLine) {
        if let stored = lineMap.remove(oriLine) {
            lineTree.remove(stored)
        }
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

    public func findExact(_ oriLine: OriLine) -> OriLine? {
        lineMap.get(oriLine)
    }

    public func findLine(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriLine> {
        let nearestItem = lineTree.findNearestInRange(pointDouble, d)
        return nearestItem.distance <= d ? nearestItem : NearestItem<OriLine>()
    }

    /// JS `getAllLines` returns a Java `Set`; the Swift facade exposes the same values as an
    /// array for the model/UI call sites (insertion order of the reference map).
    public func getAllLines() -> [OriLine] {
        lineMap.values()
    }

    /// Java/JS `Set<OriLine>` variant of `getAllLines()`.
    public func getAllLinesSet() -> JavaSet<OriLine> {
        let set = JavaSet<OriLine>()
        set.addAll(lineMap.values())
        return set
    }

    public func hasViolation() -> Bool {
        if lineTree.hasViolation() {
            return true
        }
        let iterator = lineTree.iterator()
        while iterator.hasNext() {
            if let node = iterator.next() as? RedBlackLineXNode, node.hasViolation() {
                return true
            }
        }
        return false
    }

    public func isEmpty() -> Bool {
        lineMap.isEmpty()
    }

    public func iterator() -> JavaIterator<OriLine> {
        JavaIterator(lineMap.values())
    }

    public func size() -> Int {
        lineMap.size()
    }

    public func toString() -> String {
        var sb = "RedBlackLineTree("
        var iterator = iterator()
        while iterator.hasNext() {
            sb += "\(iterator.next()), "
        }
        return sb + ")"
    }
}

extension RedBlackLineTree: Sequence {
    public func makeIterator() -> AnyIterator<OriLine> {
        var values = lineMap.values()
        var index = 0
        return AnyIterator {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }
}
