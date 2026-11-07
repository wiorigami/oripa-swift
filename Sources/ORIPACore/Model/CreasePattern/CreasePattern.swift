// Port of `com.origamitoolbox.oripa.model.creasepattern.CreasePattern`
// (oripa-port src/js/core/model/creasepattern/CreasePattern.js).
//
// Holds the point/line spatial indexes (`pointMVFB` / `lineMVFB`), the paint history and the
// flat-foldability check data (`facesCheck` / `pointErrorCheck`).
import Foundation

public final class CreasePattern {
    public let pointMVFB: RedBlackPointTree
    public let lineMVFB: RedBlackLineTree

    /// Flat-foldability check results. The Java/JS sets use identity semantics for polygons
    /// (OriPolygon has no equals/hashCode) and value semantics for points; the Swift port keeps
    /// plain arrays in insertion order per the team contract and dedupes accordingly.
    public var pointErrorCheck: [OriPoint]
    public var facesCheck: [OriPolygon]

    public var modified: Bool
    public var creasePatternHalfSize: Float
    public var inputLineType: LineType
    public var minMaxCheck: MinMaxDouble

    public let grid: GridManager
    public let historyManager: HistoryManager

    /// Contract §5.1 plain views of the spatial indexes (ordered like the JS line/point trees).
    public var lines: [OriLine] { lineMVFB.getAllLines() }

    public var points: [OriPoint] {
        var result: [OriPoint] = []
        let iterator = pointMVFB.iterator()
        while iterator.hasNext() { result.append(iterator.next()) }
        return result
    }

    /// Contract §5.1 scratch list used by the UI select tool (unused by the core algorithms).
    public var selectedLines: [OriLine] = []

    // MARK: - Init

    public init(_ creasePatternHalfSize: Float = 200.0, _ inputLineType: LineType = .mountain) {
        let pointTree = RedBlackPointTree()
        self.pointMVFB = pointTree
        self.lineMVFB = RedBlackLineTree()
        self.pointErrorCheck = []
        self.facesCheck = []
        self.modified = false
        self.creasePatternHalfSize = creasePatternHalfSize
        self.inputLineType = inputLineType
        self.minMaxCheck = pointTree.getMinMax(Double(creasePatternHalfSize))
        self.grid = GridManager(creasePatternHalfSize)
        self.historyManager = HistoryManager()
    }

    /// Java `new CreasePattern(double, byte)` convenience.
    public convenience init(_ creasePatternHalfSize: Float, _ inputLineType: Int) {
        self.init(creasePatternHalfSize, LineType(rawValue: inputLineType) ?? .undefined)
    }

    // MARK: - Adding / removing lines

    /// Java `addLineNoCheck(OriLine)`: adds the line to both spatial indexes and returns the
    /// line instance stored by the point tree (same object in the Java/JS reference).
    @discardableResult
    public func addLineNoCheck(_ oriLine: OriLine) -> OriLine {
        let added = pointMVFB.addLine(oriLine)
        lineMVFB.addLineNoCheck(added)
        return added
    }

    @discardableResult
    public func addLineNoCheck(_ oriPoint: OriPoint, _ oriPoint2: OriPoint, _ b: LineType) -> OriLine {
        addLineNoCheck(OriLine(oriPoint, oriPoint2, b))
    }

    @discardableResult
    public func addLineNoCheck(_ oriPoint: OriPoint, _ oriPoint2: OriPoint, _ b: Int) -> OriLine {
        addLineNoCheck(OriLine(oriPoint, oriPoint2, LineType(rawValue: b) ?? .undefined))
    }

    /// Java `addLineCheckNoException(OriLine)`: silently ignores duplicates (including the
    /// diagonal copy) and degenerate lines. Returns whether the line was added (JS returns void).
    @discardableResult
    public func addLineCheckNoException(_ oriLine: OriLine) -> Bool {
        if lineMVFB.contains(oriLine) || lineMVFB.contains(oriLine.diagonalCopy())
            || oriLine.start.equals(oriLine.end) {
            return false
        }
        addLineNoCheck(oriLine)
        return true
    }

    @discardableResult
    public func addLineCheckNoException(_ oriPoint: OriPoint, _ oriPoint2: OriPoint, _ b: LineType) -> Bool {
        addLineCheckNoException(OriLine(oriPoint, oriPoint2, b))
    }

    @discardableResult
    public func addLineCheckNoException(_ oriPoint: OriPoint, _ oriPoint2: OriPoint, _ b: Int) -> Bool {
        addLineCheckNoException(OriLine(oriPoint, oriPoint2, LineType(rawValue: b) ?? .undefined))
    }

    // MARK: - Line type change

    /// Java `changeLineType(OriLine, byte)`: throws `NoSuchElementException` when the line or one
    /// of its endpoints is not in the crease pattern. Swift port keeps the public method
    /// non-throwing for the UI; use `changeLineTypeChecked` to observe the Java exception path.
    public func changeLineType(_ oriLine: OriLine, _ b: LineType) {
        if !lineMVFB.contains(oriLine) || !pointMVFB.contains(oriLine.start)
            || !pointMVFB.contains(oriLine.end) {
            preconditionFailure("NoSuchElementException")
        }
        lineMVFB.changeLineType(oriLine, b)
    }

    /// Throwing variant of `changeLineType` (Java `NoSuchElementException`).
    public func changeLineTypeChecked(_ oriLine: OriLine, _ b: LineType) throws {
        if !lineMVFB.contains(oriLine) || !pointMVFB.contains(oriLine.start)
            || !pointMVFB.contains(oriLine.end) {
            throw CoreError.noSuchElement("NoSuchElementException")
        }
        lineMVFB.changeLineType(oriLine, b)
    }

    public func changeLineType(_ oriLine: OriLine, _ b: Int) {
        changeLineType(oriLine, LineType(rawValue: b) ?? .undefined)
    }

    // MARK: - Straight-line cleanup

    /// Java `cleanStraightLines(Set<OriPoint>)`: merges two collinear lines of the same type that
    /// meet at a degree-2 vertex. Returns the history items of the performed merges (the caller
    /// creates the branch).
    public func cleanStraightLines(_ set: JavaSet<OriPoint>) -> [HistoryItem] {
        var arrayList: [HistoryItem] = []
        for oriPoint in set.values() {
            if pointMVFB.contains(oriPoint) && oriPoint.getOccurrenceCount() == 2 {
                let allLineTypeCount = oriPoint.getAllLineTypeCount()
                if allLineTypeCount.isEmpty { continue }
                for b in 0..<allLineTypeCount.count where allLineTypeCount[b] == 2 {
                    let allLinesOfType = oriPoint.getAllLinesOfType(LineType(rawValue: b) ?? .undefined)
                    guard allLinesOfType.count >= 2 else { break }
                    let oriLine = allLinesOfType[0]
                    let oriLine2 = allLinesOfType[1]
                    if !GeomUtil.isCollinear(oriLine.start, oriLine.end, oriLine2.start, oriLine2.end) {
                        break
                    }
                    let historyItem = HistoryItem()
                    historyItem.oldLines.append(oriLine)
                    historyItem.oldLines.append(oriLine2)
                    removeLine(oriLine)
                    removeLine(oriLine2)
                    historyItem.newLines.append(addLineNoCheck(
                        oriLine.start.equals(oriPoint) ? oriLine.end : oriLine.start,
                        oriLine2.start.equals(oriPoint) ? oriLine2.end : oriLine2.start,
                        LineType(rawValue: b) ?? .undefined
                    ))
                    arrayList.append(historyItem)
                    break
                }
            }
        }
        return arrayList
    }

    // MARK: - Clearing

    public func clearAll() {
        historyManager.clearAll()
        pointMVFB.clear()
        lineMVFB.clear()
        clearCheckData()
    }

    public func clearCheckData() {
        facesCheck.removeAll()
        pointErrorCheck.removeAll()
    }

    // MARK: - Nearest item search

    /// Java `findLine(boolean, PointDouble, double)` (the boolean enables grid snapping).
    public func findLine(_ z: Bool, _ pointDouble: PointDouble, _ d: Double) -> OriLine? {
        let nearestItemFindLine = lineMVFB.findLine(pointDouble, d)
        if !z { return nearestItemFindLine.nearestItem }
        let nearestItemFindLine2 = grid.findLine(pointDouble, d)
        return nearestItemFindLine.distance <= nearestItemFindLine2.distance
            ? nearestItemFindLine.nearestItem
            : nearestItemFindLine2.nearestItem
    }

    /// Contract §5.1 `findLine(...)`: nearest line with the given radius.
    public func findLine(_ pointDouble: PointDouble, radius: Double) -> OriLine? {
        findLine(false, pointDouble, radius)
    }

    /// Java `findPoint(boolean, PointDouble, double)` (the boolean enables grid snapping).
    public func findPoint(_ z: Bool, _ pointDouble: PointDouble, _ d: Double) -> OriPoint? {
        let nearestItemFindPoint = pointMVFB.findPoint(pointDouble, d)
        if !z { return nearestItemFindPoint.nearestItem }
        let nearestItemFindPoint2 = grid.findPoint(pointDouble, d)
        return nearestItemFindPoint.distance <= nearestItemFindPoint2.distance
            ? nearestItemFindPoint.nearestItem
            : nearestItemFindPoint2.nearestItem
    }

    /// Contract §5.1 `findPoint(_:radius:)`: nearest point with the given radius.
    public func findPoint(_ pointDouble: PointDouble, radius: Double) -> OriPoint? {
        findPoint(false, pointDouble, radius)
    }

    // MARK: - Default square

    public func initializeDefaultSquare() {
        let halfSize = Double(creasePatternHalfSize)
        let oriPoint = OriPoint(halfSize, halfSize)
        let oriPoint2 = OriPoint(halfSize, -halfSize)
        let oriPoint3 = OriPoint(-halfSize, -halfSize)
        let oriPoint4 = OriPoint(-halfSize, halfSize)
        addLineCheckNoException(oriPoint, oriPoint2, .boundary)
        addLineCheckNoException(oriPoint2, oriPoint3, .boundary)
        addLineCheckNoException(oriPoint3, oriPoint4, .boundary)
        addLineCheckNoException(oriPoint4, oriPoint, .boundary)
    }

    // MARK: - Flat-foldability

    public func isFlatFoldable() -> Bool {
        let boundaryType = LineType.boundary.rawValue
        clearCheckData()
        minMaxCheck = pointMVFB.getMinMax(Double(creasePatternHalfSize))
        let hashSet = JavaSet<OriLine>()
        let map = JavaMap<OriPoint, HashList<OriLine>>()
        let map2 = JavaMap<OriLine, OriLine>()
        let iterator = lineMVFB.iterator()
        while iterator.hasNext() {
            let next = iterator.next()
            if next.type() == .mountain || next.type() == .valley || next.type() == .boundary {
                hashSet.add(next)
                let oriLineReverse = OriLine(next.end, next.start, next.type(), true)
                hashSet.add(oriLineReverse)
                if !map.containsKey(next.start) {
                    map.put(next.start, HashList())
                }
                if !map.containsKey(next.end) {
                    map.put(next.end, HashList())
                }
                map.get(next.start)?.add(next)
                map.get(next.end)?.add(oriLineReverse)
                map2.put(next, oriLineReverse)
                map2.put(oriLineReverse, next)
            }
        }
        let comparator: (OriLine, OriLine) -> Int = { oriLine, oriLine2 in
            let delta = GeomUtil.getAngleRadians(oriLine.start, oriLine.end)
                - GeomUtil.getAngleRadians(oriLine2.start, oriLine2.end)
            if delta > 0 { return 1 }
            if delta < 0 { return -1 }
            return 0
        }
        for list in map.values() {
            list.sort(comparator)
        }
        let hashSet2 = JavaSet<OriPolygon>()
        var oriPolygonMin: OriPolygon?
        var d = Double.greatestFiniteMagnitude
        while !hashSet.isEmpty() {
            let oriPolygon = OriPolygon()
            let oriLine2 = hashSet.values()[0]
            var i = 0
            var oriLine3 = oriLine2
            while hashSet.contains(oriLine3) {
                let bType = oriLine3.type()
                hashSet.remove(oriLine3)
                oriPolygon.points.append(oriLine3.start)
                if bType.rawValue == boundaryType { i += 1 }
                oriPolygon.lineTypes.append(bType.rawValue)
                guard let list = map.get(oriLine3.end),
                      let reverse = map2.get(oriLine3),
                      let prevLine = try? list.getPrev(reverse) else { break }
                oriLine3 = prevLine
            }
            guard let startList = map.get(oriLine2.start),
                  let firstNext = try? startList.getNext(oriLine2),
                  let reversed = map2.get(firstNext) else { continue }
            var obj = reversed
            while true {
                let oriLine4 = obj
                if !hashSet.contains(oriLine4) { break }
                let bType2 = oriLine4.type()
                hashSet.remove(oriLine4)
                oriPolygon.points.insert(oriLine4.start, at: 0)
                if bType2.rawValue == boundaryType { i += 1 }
                oriPolygon.lineTypes.insert(bType2.rawValue, at: 0)
                guard let list = map.get(oriLine4.start),
                      let nextLine4Value = try? list.getNext(oriLine4),
                      let reversed4 = map2.get(nextLine4Value) else { break }
                obj = reversed4
            }
            var i2 = 0
            var size = oriPolygon.points.count
            while i2 < size && size >= 3 {
                let oriPoint = oriPolygon.points[i2]
                let i3 = i2 - 1
                let oriPoint2 = oriPolygon.points[GeomUtil.clamp(i3, size)]
                let i4 = i2 + 1
                let oriPoint3 = oriPolygon.points[GeomUtil.clamp(i4, size)]
                let lineTypeValue = oriPolygon.lineTypes[i2]
                let lineTypeValue2 = oriPolygon.lineTypes[GeomUtil.clamp(i3, size)]
                if GeomUtil.isCollinear(oriPoint2, oriPoint, oriPoint, oriPoint3)
                    && lineTypeValue2 == lineTypeValue {
                    if lineTypeValue == boundaryType { i -= 1 }
                    oriPolygon.points.remove(at: i2)
                    oriPolygon.lineTypes.remove(at: i2)
                    size = oriPolygon.points.count
                } else {
                    i2 = i4
                }
            }
            if size >= 3 {
                addFaceCheck(oriPolygon)
                if i == size {
                    hashSet2.add(oriPolygon)
                }
                let area = oriPolygon.getArea()
                if area < d {
                    d = area
                    oriPolygonMin = oriPolygon
                }
            }
        }
        if d < 0.0, let oriPolygonMin {
            removeFaceCheck(oriPolygonMin)
            hashSet2.remove(oriPolygonMin)
        }
        if facesCheck.count > 1 {
            for polygon in hashSet2.values() {
                removeFaceCheck(polygon)
            }
        }
        let pointIterator = pointMVFB.iterator()
        while pointIterator.hasNext() {
            let oriPoint4 = pointIterator.next()
            if let list = map.get(oriPoint4), !oriPoint4.isFlatFoldable(list.getList()) {
                if !pointErrorCheck.contains(where: { $0.equals(oriPoint4) }) {
                    pointErrorCheck.append(oriPoint4)
                }
            }
        }
        return pointErrorCheck.isEmpty && !facesCheck.isEmpty
    }

    // MARK: - Check-data helpers (JavaSet<OriPolygon> identity semantics as arrays)

    public func addFaceCheck(_ polygon: OriPolygon) {
        if !facesCheck.contains(where: { $0 === polygon }) {
            facesCheck.append(polygon)
        }
    }

    public func removeFaceCheck(_ polygon: OriPolygon) {
        facesCheck.removeAll { $0 === polygon }
    }

    // MARK: - Removal

    /// Java `removeLine(OriLine)`.
    public func removeLine(_ oriLine: OriLine) {
        lineMVFB.removeLine(oriLine)
        pointMVFB.removeLine(oriLine)
    }
}
