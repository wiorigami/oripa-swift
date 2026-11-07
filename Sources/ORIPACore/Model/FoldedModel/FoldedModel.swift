// Port of `com.origamitoolbox.oripa.model.foldedmodel.FoldedModel`
// (oripa-port src/js/core/model/foldedmodel/FoldedModel.js).
//
// The fold engine, two stages like the Android app:
//   foldWithoutOverlap(cp) : builds mVertices/mHalfEdges/mFaces from CreasePattern.facesCheck
//                            and computes each vertex's valueAfterFold (2D flattened coordinates)
//                            and each face's transformMatrix.
//   foldWithOverlap()      : builds the face draw order (sortedFaces/sortedFacesReverse) from the
//                            face adjacency graph (DirectedGraph/DirectedNode).
//
// Android `android.opengl.Matrix` is replaced by the private column-major `[Float]` matrix
// helpers below (same operation order and float rounding as the Java; the JS reference keeps
// `Float32Array` matrices with double intermediate arithmetic, which this port mirrors exactly).
// `GLUtil.getTransformedPointDouble` (owned by core-model) produces the doubled-precision
// `valueAfterFold` positions. The documented fold-audit fixes are preserved:
//   * boundary-scan retry (`currentFace = nil; continue`) instead of seeding a bogus component;
//   * Java `HashSet<OriHalfEdge>` iteration order for the per-face edge walks;
//   * per-component draw order + final list reversal of `foldWithOverlap`.
import Foundation

// MARK: - Ordered identity collections (JS Set/Map insertion-order semantics)

/// JS `Set` with object identity: insertion-ordered, which the reference `FoldedModel.js`
/// deliberately uses so the fold walk is deterministic (Java `HashSet` order would be
/// identity-hash order; the JS port kept insertion order — see fold-audit.md §4).
struct FoldedIdentityOrderedSet<Element: AnyObject> {
    private var items: [Element]
    private var ids: Set<ObjectIdentifier>

    init() {
        self.items = []
        self.ids = []
    }

    @discardableResult
    mutating func add(_ element: Element) -> Bool {
        let id = ObjectIdentifier(element)
        guard !ids.contains(id) else { return false }
        ids.insert(id)
        items.append(element)
        return true
    }

    @discardableResult
    mutating func remove(_ element: Element) -> Bool {
        let id = ObjectIdentifier(element)
        guard ids.remove(id) != nil else { return false }
        if let index = items.firstIndex(where: { $0 === element }) {
            items.remove(at: index)
        }
        return true
    }

    func contains(_ element: Element) -> Bool {
        ids.contains(ObjectIdentifier(element))
    }

    var count: Int { items.count }
    var isEmpty: Bool { items.isEmpty }
    var first: Element? { items.first }

    /// Snapshot in iteration order (callers loop over a copy like the JS `for...of`).
    func array() -> [Element] { items }
}

/// JS `Map` with object identity keys and insertion-order iteration (the reference's
/// `valueToNodeMap`/`counts` in `DirectedGraph`); removal keeps the remaining insertion order.
struct FoldedIdentityOrderedMap<Key: AnyObject, Value> {
    private var keys: [Key]
    private var values: [Value]
    private var indices: [ObjectIdentifier: Int]

    init() {
        self.keys = []
        self.values = []
        self.indices = [:]
    }

    mutating func set(_ key: Key, _ value: Value) {
        let id = ObjectIdentifier(key)
        if let index = indices[id] {
            values[index] = value
            return
        }
        indices[id] = keys.count
        keys.append(key)
        values.append(value)
    }

    func get(_ key: Key) -> Value? {
        guard let index = indices[ObjectIdentifier(key)] else { return nil }
        return values[index]
    }

    func contains(_ key: Key) -> Bool {
        indices[ObjectIdentifier(key)] != nil
    }

    @discardableResult
    mutating func remove(_ key: Key) -> Value? {
        let id = ObjectIdentifier(key)
        guard let index = indices[id] else { return nil }
        let value = values[index]
        indices.removeValue(forKey: id)
        keys.remove(at: index)
        values.remove(at: index)
        for i in index..<keys.count {
            indices[ObjectIdentifier(keys[i])] = i
        }
        return value
    }

    var count: Int { keys.count }
    var isEmpty: Bool { keys.isEmpty }

    /// Insertion-order `(key, value)` snapshot.
    func entries() -> [(Key, Value)] {
        Array(zip(keys, values))
    }
}

/// Stable sort with a Java/JS `Comparator`-style result (-1/0/1); ties keep insertion order
/// like `Array.prototype.sort`/`Collections.sort` (Swift's `sort` is not stable).
fileprivate func stableSorted<T>(_ items: [T], _ compare: (T, T) -> Int) -> [T] {
    items.enumerated().sorted { lhs, rhs in
        let result = compare(lhs.element, rhs.element)
        if result != 0 { return result < 0 }
        return lhs.offset < rhs.offset
    }.map { $0.element }
}

/// Java `Integer.signum(a - b)` result for the graph height comparators.
fileprivate func compareInts(_ a: Int, _ b: Int) -> Int {
    if a < b { return -1 }
    if a > b { return 1 }
    return 0
}

// MARK: - Matrix helpers

/// Private subset of `android.opengl.Matrix` used by `FoldedModel.js` (column-major
/// `Float32Array`). Matrix entries are Android `float`s: every store rounds to `Float`, while the
/// intermediate arithmetic is done in `Double` exactly like the JS reference (which also mirrors
/// Java's `Math.fround` calls at the same spots).
fileprivate enum FoldedModelMatrix {
    static func setIdentityM(_ m: inout [Float], _ offset: Int) {
        for i in 0..<16 { m[offset + i] = 0 }
        m[offset] = 1
        m[offset + 5] = 1
        m[offset + 10] = 1
        m[offset + 15] = 1
    }

    /// `Matrix.translateM`: m = m * T(x, y, z).
    static func translateM(_ m: inout [Float], _ offset: Int, _ x: Double, _ y: Double, _ z: Double) {
        for i in 0..<4 {
            let mi = offset + i
            let delta = (Double(m[mi]) * x) + (Double(m[4 + mi]) * y) + (Double(m[8 + mi]) * z)
            m[12 + mi] = Float(Double(m[12 + mi]) + delta)
        }
    }

    /// `Matrix.scaleM`: m = m * S(x, y, z).
    static func scaleM(_ m: inout [Float], _ offset: Int, _ x: Double, _ y: Double, _ z: Double) {
        for i in 0..<4 {
            let mi = offset + i
            m[mi] = Float(Double(m[mi]) * x)
            m[4 + mi] = Float(Double(m[4 + mi]) * y)
            m[8 + mi] = Float(Double(m[8 + mi]) * z)
        }
    }

    /// `Matrix.setRotateM` as inlined by `FoldedModel.js` (general axis-angle form with
    /// `Math.fround` on the angle/sin/cos, which the Java bytecode does in float arithmetic).
    static func setRotateM(_ rm: inout [Float], _ offset: Int,
                           _ aDeg: Double, _ x: Double, _ y: Double, _ z: Double) {
        var x = x
        var y = y
        var z = z
        let len = sqrt((x * x) + (y * y) + (z * z))
        if len == 0 { return }
        x /= len
        y /= len
        z /= len
        let a = Float((aDeg * Double.pi) / 180.0)
        let c = Float(cos(Double(a)))
        let s = Float(sin(Double(a)))
        let c1 = Float(1.0 - Double(c))
        let cd = Double(c)
        let sd = Double(s)
        let c1d = Double(c1)
        rm[offset] = Float((x * x * c1d) + cd)
        rm[offset + 1] = Float((y * x * c1d) + (z * sd))
        rm[offset + 2] = Float((x * z * c1d) - (y * sd))
        rm[offset + 3] = 0
        rm[offset + 4] = Float((x * y * c1d) - (z * sd))
        rm[offset + 5] = Float((y * y * c1d) + cd)
        rm[offset + 6] = Float((y * z * c1d) + (x * sd))
        rm[offset + 7] = 0
        rm[offset + 8] = Float((x * z * c1d) + (y * sd))
        rm[offset + 9] = Float((y * z * c1d) - (x * sd))
        rm[offset + 10] = Float((z * z * c1d) + cd)
        rm[offset + 11] = 0
        rm[offset + 12] = 0
        rm[offset + 13] = 0
        rm[offset + 14] = 0
        rm[offset + 15] = 1
    }

    /// `Matrix.rotateM`: m = m * R(a, x, y, z).
    static func rotateM(_ m: inout [Float], _ offset: Int,
                        _ aDeg: Double, _ x: Double, _ y: Double, _ z: Double) {
        var rm = [Float](repeating: 0, count: 16)
        var tmp = [Float](repeating: 0, count: 16)
        setRotateM(&rm, 0, aDeg, x, y, z)
        multiplyMM(&tmp, 0, m, offset, rm, 0)
        for i in 0..<16 { m[offset + i] = tmp[i] }
    }

    /// `Matrix.multiplyMM`: result = lhs * rhs (column-major). `result` must not alias the inputs.
    static func multiplyMM(_ result: inout [Float], _ resultOffset: Int,
                           _ lhs: [Float], _ lhsOffset: Int,
                           _ rhs: [Float], _ rhsOffset: Int) {
        for i in 0..<4 {
            for j in 0..<4 {
                var sum = 0.0
                for k in 0..<4 {
                    sum += Double(lhs[lhsOffset + (k * 4) + j]) * Double(rhs[rhsOffset + (i * 4) + k])
                }
                result[resultOffset + (i * 4) + j] = Float(sum)
            }
        }
    }

    /// `GLUtil.getTransformedPointDouble` with the JS `Math.fround` casts on the point: the
    /// result is a double computed from float matrix entries (not rounded back to float).
    static func transformPointDouble(_ m: [Float], _ x: Double, _ y: Double) -> PointDouble {
        GLUtil.getTransformedPointDouble(m, Float(x), Float(y))
    }
}

// MARK: - Java HashSet<OriHalfEdge> iteration order

/// Java `OriPoint.getKey`-based `OriVertex.hashCode()`; int32 wrapping like the Java ints.
fileprivate func javaVertexHash(_ vertex: OriVertex) -> Int32 {
    Int32(truncatingIfNeeded: OriPoint.getKey(vertex.x)) &* 31
        &+ Int32(truncatingIfNeeded: OriPoint.getKey(vertex.y))
}

/// Java `OriHalfEdge.hashCode()`: `start.hashCode() * 31 + end.hashCode()`.
fileprivate func javaHalfEdgeHash(_ halfEdge: OriHalfEdge) -> Int32 {
    javaVertexHash(halfEdge.start) &* 31 &+ javaVertexHash(halfEdge.end)
}

/// `java.util.HashMap` table size after inserting `n` elements: default 16, load factor 0.75,
/// doubles on resize.
fileprivate func javaHashSetCapacity(_ n: Int) -> Int {
    var capacity = 16
    while n > (capacity * 3) / 4 {
        capacity *= 2
    }
    return capacity
}

/// `java.util.HashSet<OriHalfEdge>` iteration order: bucket index ascending (bucket =
/// `HashMap.hash(h) & (capacity - 1)`), insertion order within a bucket.
fileprivate func javaHashSetIterationOrder(_ elements: [OriHalfEdge]) -> [OriHalfEdge] {
    let capacity = javaHashSetCapacity(elements.count)
    var entries: [(element: OriHalfEdge, index: Int, bucket: Int)] = []
    entries.reserveCapacity(elements.count)
    for (index, element) in elements.enumerated() {
        let hash = javaHalfEdgeHash(element)
        // java.util.HashMap.hash: h ^ (h >>> 16), as an int.
        let shifted = Int32(bitPattern: UInt32(bitPattern: hash) >> 16)
        let spread = hash ^ shifted
        let bucket = Int(spread & Int32(capacity - 1))
        entries.append((element: element, index: index, bucket: bucket))
    }
    entries.sort { lhs, rhs in
        if lhs.bucket != rhs.bucket { return lhs.bucket < rhs.bucket }
        return lhs.index < rhs.index
    }
    return entries.map { $0.element }
}

// MARK: - FoldedModel

public final class FoldedModel {
    // MARK: DirectedNode / DirectedGraph (Java static nested classes)

    /// Java `static class FoldedModel.DirectedNode<T>`.
    final class DirectedNode<T: AnyObject> {
        let value: T
        var bottomToTopHeight = 0
        var topToBottomHeight = 0
        var parents = FoldedIdentityOrderedSet<DirectedNode<T>>()
        var children = FoldedIdentityOrderedSet<DirectedNode<T>>()

        init(_ value: T) {
            self.value = value
        }

        func toString() -> String {
            var text = "DirectedNode(["
            for parent in parents.array() {
                text += String(describing: parent.value)
                text += ","
            }
            text += "]->"
            text += String(describing: value)
            text += "->["
            for child in children.array() {
                text += String(describing: child.value)
                text += ","
            }
            text += "], height = {\(bottomToTopHeight): \(topToBottomHeight)})"
            return text
        }
    }

    /// Java `static class FoldedModel.DirectedGraph<T>`; `valueToNodeMap` is a `HashMap` in the
    /// Java but the JS reference keeps insertion order, preserved here.
    final class DirectedGraph<T: AnyObject> {
        private var nodes: [DirectedNode<T>] = []
        private var valueToNodeMap: [ObjectIdentifier: DirectedNode<T>] = [:]

        init() {}

        func node(for value: T) -> DirectedNode<T>? {
            valueToNodeMap[ObjectIdentifier(value)]
        }

        func contains(_ value: T) -> Bool {
            valueToNodeMap[ObjectIdentifier(value)] != nil
        }

        @discardableResult
        func put(_ value: T) -> DirectedNode<T> {
            let id = ObjectIdentifier(value)
            if let node = valueToNodeMap[id] { return node }
            let node = DirectedNode(value)
            valueToNodeMap[id] = node
            nodes.append(node)
            return node
        }

        private func heightComparator(_ topToBottom: Bool) -> (DirectedNode<T>, DirectedNode<T>) -> Int {
            if topToBottom {
                return { compareInts($0.topToBottomHeight, $1.topToBottomHeight) }
            }
            return { compareInts($0.bottomToTopHeight, $1.bottomToTopHeight) }
        }

        /// Draw order: z == false walks bottom->top along children, z == true walks top->bottom
        /// along parents. Nodes left over from a cycle are broken by fewest unsolved neighbours.
        func getDrawOrder(_ z: Bool) -> [T] {
            var result: [T] = []
            var counts = FoldedIdentityOrderedMap<DirectedNode<T>, FoldedIdentityOrderedSet<DirectedNode<T>>>()
            var roots: [DirectedNode<T>] = []
            for node in nodes {
                let unsolved = z ? node.children : node.parents
                if unsolved.isEmpty {
                    roots.append(node)
                } else {
                    counts.set(node, unsolved)
                }
            }
            roots = stableSorted(roots, heightComparator(z))
            var stack: [DirectedNode<T>] = []
            for root in roots { stack.append(root) }
            while let node = stack.popLast() {
                result.append(node.value)
                let next = z ? node.parents : node.children
                for neighbor in next.array() {
                    guard var unsolved = counts.get(neighbor) else { continue }
                    unsolved.remove(node)
                    if unsolved.isEmpty {
                        stack.append(neighbor)
                        counts.remove(neighbor)
                    } else {
                        counts.set(neighbor, unsolved)
                    }
                }
            }
            while counts.count > 0 {
                var pick: DirectedNode<T>?
                var pickSize = Int.max
                for (node, unsolved) in counts.entries() where unsolved.count < pickSize {
                    pick = node
                    pickSize = unsolved.count
                }
                guard let picked = pick else { break }
                counts.remove(picked)
                stack.append(picked)
                while let forced = stack.popLast() {
                    result.append(forced.value)
                    let next = z ? forced.parents : forced.children
                    for neighbor in next.array() {
                        guard var remaining = counts.get(neighbor) else { continue }
                        remaining.remove(forced)
                        if remaining.isEmpty {
                            stack.append(neighbor)
                            counts.remove(neighbor)
                        } else {
                            counts.set(neighbor, remaining)
                        }
                    }
                }
            }
            return result
        }

        /// Java package-private `List<DirectedNode<T>> getTopologicalSort(boolean z)`.
        func getTopologicalSort(_ z: Bool) -> [DirectedNode<T>] {
            var result: [DirectedNode<T>] = []
            var stack: [DirectedNode<T>] = []
            var counts = FoldedIdentityOrderedMap<DirectedNode<T>, FoldedIdentityOrderedSet<DirectedNode<T>>>()
            for node in nodes {
                let unsolved = z ? node.children : node.parents
                if unsolved.isEmpty {
                    stack.append(node)
                } else {
                    counts.set(node, unsolved)
                }
            }
            while let node = stack.popLast() {
                result.append(node)
                let next = z ? node.parents : node.children
                for neighbor in next.array() {
                    guard var unsolved = counts.get(neighbor) else { continue }
                    unsolved.remove(node)
                    if unsolved.isEmpty {
                        stack.append(neighbor)
                        counts.remove(neighbor)
                    } else {
                        counts.set(neighbor, unsolved)
                    }
                }
            }
            return result
        }

        func updateHeights() {
            for node in getTopologicalSort(true) {
                for child in node.children.array() {
                    node.bottomToTopHeight = max(node.bottomToTopHeight, child.bottomToTopHeight + 1)
                }
            }
            for node in getTopologicalSort(false) {
                for parent in node.parents.array() {
                    node.topToBottomHeight = max(node.topToBottomHeight, parent.topToBottomHeight + 1)
                }
            }
        }

        func toString() -> String {
            var text = "\(nodes.count) faces: DirectedGraph("
            for node in nodes { text += node.toString() }
            text += ")"
            return text
        }
    }

    // MARK: Fields (Java public final fields)

    public let crossLine: CrossLine
    public let foldedModelHalfSize: Double
    public var mFaces: [OriFace]
    public var mVertices: [OriVertex]
    public var mHalfEdges: [OriHalfEdge]
    public var sortedFaces: [OriFace]
    public var sortedFacesReverse: [OriFace]

    /// Diagnostic added by the JS port: connected components started by the fold walk.
    public private(set) var componentCount: Int

    /// Java has `public FoldedModel()` and a private `FoldedModel(double)`; the JS constructor's
    /// optional argument keeps the private constructor's role.
    public init(foldedModelHalfSize: Double = 200.0) {
        self.foldedModelHalfSize = foldedModelHalfSize
        self.crossLine = CrossLine(foldedModelHalfSize)
        self.mFaces = []
        self.mVertices = []
        self.mHalfEdges = []
        self.sortedFaces = []
        self.sortedFacesReverse = []
        self.componentCount = 0
    }

    public func clear() {
        mFaces.removeAll()
        mVertices.removeAll()
        mHalfEdges.removeAll()
        sortedFaces.removeAll()
        sortedFacesReverse.removeAll()
        componentCount = 0
    }

    // MARK: - foldWithOverlap

    public func foldWithOverlap() {
        var remaining = FoldedIdentityOrderedSet<OriFace>()
        for face in mFaces { remaining.add(face) }
        var graphs: [DirectedGraph<OriFace>] = []
        while !remaining.isEmpty {
            let graph = DirectedGraph<OriFace>()
            var queue: [OriFace] = []
            var queueHead = 0
            guard let first = remaining.first else { break }
            remaining.remove(first)
            queue.append(first)
            graph.put(first)
            while queueHead < queue.count {
                let face = queue[queueHead]
                queueHead += 1
                guard let node = graph.node(for: face) else { continue }
                for halfEdge in face.halfEdges {
                    if halfEdge.lineType == 1 { continue }
                    guard let twin = halfEdge.twin, let twinFace = twin.face else { continue }
                    let twinNode: DirectedNode<OriFace>
                    if let existing = graph.node(for: twinFace) {
                        twinNode = existing
                    } else {
                        remaining.remove(twinFace)
                        queue.append(twinFace)
                        twinNode = graph.put(twinFace)
                    }
                    // Java: !((face.isCCW && lineType == 2) || (!face.isCCW && lineType == 3))
                    let flip = (face.isCCWOrientation && halfEdge.lineType == 2)
                        || (!face.isCCWOrientation && halfEdge.lineType == 3)
                    if !flip {
                        node.parents.add(twinNode)
                        twinNode.children.add(node)
                    } else {
                        node.children.add(twinNode)
                        twinNode.parents.add(node)
                    }
                }
            }
            graph.updateHeights()
            graphs.append(graph)
        }
        for graph in graphs {
            for face in graph.getDrawOrder(false) {
                sortedFaces.append(face)
            }
        }
        for graph in graphs.reversed() {
            for face in graph.getDrawOrder(true) {
                sortedFacesReverse.append(face)
            }
        }
        sortedFaces.reverse()
        sortedFacesReverse.reverse()
    }

    // MARK: - foldWithoutOverlap

    public func foldWithoutOverlap(_ creasePattern: CreasePattern) {
        foldWithoutOverlap(facesCheck: creasePattern.facesCheck)
    }

    /// The JS fixture generator calls `fm.foldWithoutOverlap({ creasePatternHalfSize, facesCheck })`
    /// (the engine only reads `facesCheck`); this overload keeps that call shape available without
    /// constructing a full `CreasePattern`.
    public func foldWithoutOverlap(facesCheck: [OriPolygon]) {
        clear()
        let vertexList = HashList<OriVertex>()       // Java: HashList<OriVertex>, value semantics
        var halfEdgeMap: [String: Int] = [:]         // Java: HashMap<OriHalfEdge,Integer> (equals on vertices)
        var faceEdgeSets: [FoldedIdentityOrderedSet<OriHalfEdge>] = []   // Java: ArrayList<HashSet<OriHalfEdge>>
        var faceEdgeOrders: [[OriHalfEdge]] = []     // Java HashSet iteration order of each face's edges

        for polygon in facesCheck {
            let face = OriFace(mFaces.count)
            var edgeSet = FoldedIdentityOrderedSet<OriHalfEdge>()
            var edgeList: [OriHalfEdge] = []
            let size = polygon.points.count
            for i in 0..<size {
                let point = polygon.points[i]
                let point2 = polygon.points[GeomUtil.clamp(i + 1, size)]
                let lineType = polygon.lineTypes[i]
                var vertex = OriVertex(point: point, index: vertexList.size())
                if !vertexList.add(vertex) {
                    vertex = (try? vertexList.getElement(vertex)) ?? vertex
                }
                var vertex2 = OriVertex(point: point2, index: vertexList.size())
                if !vertexList.add(vertex2) {
                    vertex2 = (try? vertexList.getElement(vertex2)) ?? vertex2
                }
                let halfEdge = OriHalfEdge(vertex, vertex2, lineType)
                face.halfEdges.append(halfEdge)
                halfEdge.face = face
                // Java HashMap key: OriHalfEdge.equals compares start/end vertices only.
                halfEdgeMap["\(vertex.index),\(vertex2.index)"] = mHalfEdges.count
                mHalfEdges.append(halfEdge)
                edgeSet.add(halfEdge)
                edgeList.append(halfEdge)
            }
            mFaces.append(face)
            faceEdgeSets.append(edgeSet)
            faceEdgeOrders.append(javaHashSetIterationOrder(edgeList))
        }

        if mFaces.isEmpty {
            // Java would throw NoSuchElementException on the seed above; the UI checks
            // isFlatFoldable() first, but renderers/tests may fold an empty model, so return an
            // empty model instead of crashing (JS port guard).
            return
        }

        mVertices.append(contentsOf: vertexList.getList())

        // Twin edges: reversed half-edge lookup by vertex pair (Java uses the HashMap with value
        // equality, mirrored here by the vertex-index key).
        for halfEdge in mHalfEdges {
            if let reversedIndex = halfEdgeMap["\(halfEdge.end.index),\(halfEdge.start.index)"] {
                halfEdge.twin = mHalfEdges[reversedIndex]
            }
        }

        var boundary = FoldedIdentityOrderedSet<OriFace>()    // Java: hashSet2 (faces still on the frontier)
        var unprocessed = FoldedIdentityOrderedSet<OriFace>() // Java: hashSet3
        for face in mFaces { unprocessed.add(face) }
        guard let seed = unprocessed.first else { return }
        for halfEdge in seed.halfEdges {
            halfEdge.end.valueAfterFold = PointDouble(halfEdge.end)
        }
        var z = true                       // Java: boolean z = true (never set false in the bytecode)
        seed.isCCWOrientation = true
        FoldedModelMatrix.setIdentityM(&seed.transformMatrix, 0)
        boundary.add(seed)
        unprocessed.remove(seed)
        componentCount += 1

        var currentFace: OriFace? = seed
        while !unprocessed.isEmpty {
            var chosen: OriHalfEdge?

            if let face = currentFace {
                var consumed = FoldedIdentityOrderedSet<OriHalfEdge>()
                let edgeIndex = face.index
                let edges = faceEdgeSets[edgeIndex]
                for halfEdge in faceEdgeOrders[edgeIndex] {
                    if !edges.contains(halfEdge) { continue }
                    consumed.add(halfEdge)
                    if let twin = halfEdge.twin,
                       let twinFace = twin.face,
                       faceEdgeSets[twinFace.index].count > 0,
                       unprocessed.contains(twinFace) {
                        chosen = twin
                        break
                    }
                }
                for consumedEdge in consumed.array() {
                    faceEdgeSets[edgeIndex].remove(consumedEdge)
                }
                if faceEdgeSets[edgeIndex].isEmpty {
                    boundary.remove(face)
                }
                if let chosen {
                    currentFace = chosen.face
                    if let nextFace = chosen.face {
                        faceEdgeSets[nextFace.index].remove(chosen)
                    }
                } else {
                    /* jadx artifact: the Android bytecode jumps back to the loop head
                     * (FoldedModel.smali `goto :goto_4`) with currentFace = null, so the NEXT
                     * iteration runs the boundary-scan branch below and reconnects through the
                     * frontier. Falling through to the "new component" seed strands faces and
                     * makes valid patterns fold into mutually inconsistent pieces. */
                    currentFace = nil
                    continue
                }
            } else {
                var finished = FoldedIdentityOrderedSet<OriFace>()
                for boundaryFace in boundary.array() {
                    if faceEdgeSets[boundaryFace.index].count > 0 {
                        var consumed = FoldedIdentityOrderedSet<OriHalfEdge>()
                        for halfEdge in faceEdgeOrders[boundaryFace.index] {
                            if !faceEdgeSets[boundaryFace.index].contains(halfEdge) { continue }
                            consumed.add(halfEdge)
                            if let twin = halfEdge.twin,
                               let twinFace = twin.face,
                               faceEdgeSets[twinFace.index].count > 0,
                               unprocessed.contains(twinFace) {
                                chosen = twin
                                break
                            }
                        }
                        for consumedEdge in consumed.array() {
                            faceEdgeSets[boundaryFace.index].remove(consumedEdge)
                        }
                        if faceEdgeSets[boundaryFace.index].isEmpty {
                            finished.add(boundaryFace)
                        }
                        if let chosen {
                            currentFace = chosen.face
                            if let nextFace = chosen.face {
                                faceEdgeSets[nextFace.index].remove(chosen)
                            }
                            break
                        }
                    }
                }
                for finishedFace in finished.array() {
                    boundary.remove(finishedFace)
                }
            }

            if chosen == nil {
                // Start a new connected component: identity transform, keep CP coordinates.
                guard let nextFace = unprocessed.first else { break }
                currentFace = nextFace
                for halfEdge in nextFace.halfEdges {
                    halfEdge.end.valueAfterFold = PointDouble(halfEdge.end)
                }
                nextFace.isCCWOrientation = z
                FoldedModelMatrix.setIdentityM(&nextFace.transformMatrix, 0)
                boundary.add(nextFace)
                unprocessed.remove(nextFace)
                componentCount += 1
            } else if let chosen, let face = currentFace, let hingeFace = chosen.twin?.face {
                // Fold the neighbour face over the shared edge (2D reflection in the plane):
                // translate hinge midpoint to origin, flip x, rotate back.
                let hingeX = Float((chosen.start.x + chosen.end.x) / 2.0)
                let hingeY = Float((chosen.start.y + chosen.end.y) / 2.0)
                let degrees = (GeomUtil.getAngleRadians(chosen.start, chosen.end) * 180.0) / Double.pi
                let adjusted = degrees < 0.0 ? degrees + 180.0 : degrees
                let f = Float(90.0 - adjusted)
                FoldedModelMatrix.setIdentityM(&face.transformMatrix, 0)
                FoldedModelMatrix.translateM(&face.transformMatrix, 0, Double(hingeX), Double(hingeY), 0.0)
                FoldedModelMatrix.rotateM(&face.transformMatrix, 0, Double(f), 0.0, 0.0, -1.0)
                FoldedModelMatrix.scaleM(&face.transformMatrix, 0, -1.0, 1.0, 1.0)
                FoldedModelMatrix.rotateM(&face.transformMatrix, 0, Double(f), 0.0, 0.0, 1.0)
                FoldedModelMatrix.translateM(&face.transformMatrix, 0, -Double(hingeX), -Double(hingeY), 0.0)
                var combined = [Float](repeating: 0, count: 16)
                FoldedModelMatrix.multiplyMM(&combined, 0, hingeFace.transformMatrix, 0, face.transformMatrix, 0)
                for m in 0..<16 { face.transformMatrix[m] = combined[m] }
                for halfEdge in face.halfEdges where halfEdge.end.valueAfterFold == nil {
                    halfEdge.end.valueAfterFold = FoldedModelMatrix.transformPointDouble(
                        face.transformMatrix, halfEdge.end.x, halfEdge.end.y)
                }
                face.isCCWOrientation = !hingeFace.isCCWOrientation
                if faceEdgeSets[face.index].count > 0 {
                    boundary.add(face)
                }
                unprocessed.remove(face)
                z = true
            }
        }

        // Fit the folded model into [-foldedModelHalfSize, foldedModelHalfSize].
        let minMax = MinMaxDouble()
        for vertex in mVertices {
            guard let folded = vertex.valueAfterFold else { continue }
            minMax.minX = min(minMax.minX, folded.x)
            minMax.minY = min(minMax.minY, folded.y)
            minMax.maxX = max(minMax.maxX, folded.x)
            minMax.maxY = max(minMax.maxY, folded.y)
        }
        // Java builds the centre as android.graphics.PointF (float components).
        let centerX = Float((minMax.maxX + minMax.minX) / 2.0)
        let centerY = Float((minMax.maxY + minMax.minY) / 2.0)
        let scale = Float(min(
            foldedModelHalfSize / (minMax.maxY - Double(centerY)),
            foldedModelHalfSize / (minMax.maxX - Double(centerX))))
        var fit = [Float](repeating: 0, count: 16)
        FoldedModelMatrix.setIdentityM(&fit, 0)
        FoldedModelMatrix.scaleM(&fit, 0, Double(scale), Double(scale), 1.0)
        FoldedModelMatrix.translateM(&fit, 0, -Double(centerX), -Double(centerY), 0.0)
        for vertex in mVertices {
            guard let folded = vertex.valueAfterFold else { continue }
            vertex.valueAfterFold = FoldedModelMatrix.transformPointDouble(fit, folded.x, folded.y)
        }
        for face in mFaces {
            var combined = [Float](repeating: 0, count: 16)
            FoldedModelMatrix.multiplyMM(&combined, 0, fit, 0, face.transformMatrix, 0)
            for m in 0..<16 { face.transformMatrix[m] = combined[m] }
        }
    }
}
