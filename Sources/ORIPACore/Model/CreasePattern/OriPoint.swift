// Port of `com.origamitoolbox.oripa.model.creasepattern.OriPoint`
// (oripa-port src/js/core/model/creasepattern/OriPoint.js).
//
// Java `OriPoint extends PointDouble implements Comparable<OriPoint>`; value equality uses the
// quantized `xKey`/`yKey` (1e-3) instead of exact coordinates.
import Foundation

open class OriPoint: PointDouble, Comparable {
    public static let NUM_PRECISION = 1000
    public static let STRIDE = 2

    /// Java `short[4]` line-type counters; the JS port grows the array when a line type >= 4 is
    /// added (real .cp files contain GRID lines), so this is a growable `[Int]`.
    private var lineTypeCount: [Int]
    private var _lines: [OriLine]
    public let xKey: Int
    public let yKey: Int

    public override init(_ x: Double, _ y: Double) {
        self._lines = []
        self.lineTypeCount = [0, 0, 0, 0]
        self.xKey = OriPoint.getKey(x)
        self.yKey = OriPoint.getKey(y)
        super.init(x, y)
    }

    /// Java copy constructor: `new OriPoint(PointDouble)`.
    public override init(_ pointDouble: PointDouble) {
        self._lines = []
        self.lineTypeCount = [0, 0, 0, 0]
        self.xKey = OriPoint.getKey(pointDouble.x)
        self.yKey = OriPoint.getKey(pointDouble.y)
        super.init(pointDouble.x, pointDouble.y)
    }

    /// Java `(int) Math.round(d * 1000.0d)`, with JS `Math.round` semantics.
    public static func getKey(_ d: Double) -> Int {
        JavaMath.roundToInt(d * Double(NUM_PRECISION))
    }

    public var lines: [OriLine] { _lines }

    // MARK: - Flat-foldability checks

    /// Kawasaki's theorem. The passed list is the angle-sorted list of lines at this vertex
    /// (see `CreasePattern.isFlatFoldable`); the decompiled `list == null` branch is the
    /// equivalent in-place test. Only mountain/valley lines participate.
    public func checkKawasaki(_ list: [OriLine]?) -> Bool {
        if let list {
            var angles: [Double] = []
            for line in list where line.type() == .mountain || line.type() == .valley {
                angles.append(GeomUtil.getAngleRadians(self, line.start.equals(self) ? line.end : line.start))
            }
            var sum = 0.0
            var i = 1
            while i < angles.count {
                var delta = angles[i] - angles[i - 1]
                delta = delta.truncatingRemainder(dividingBy: GeomUtil.TWO_PI)
                if delta < 0.0 { delta += GeomUtil.TWO_PI }
                sum += delta
                i += 2
            }
            return abs(sum - GeomUtil.PI) <= GeomUtil.EPS
        }
        var angleList: [Double] = []
        for line in _lines where line.type() == .mountain || line.type() == .valley {
            angleList.append(GeomUtil.getAngleRadians(self, line.start.equals(self) ? line.end : line.start))
        }
        angleList.sort()
        var sum = 0.0
        var i = 1
        while i < angleList.count {
            var delta = angleList[i] - angleList[i - 1]
            delta = delta.truncatingRemainder(dividingBy: GeomUtil.TWO_PI)
            if delta < 0.0 { delta += GeomUtil.TWO_PI }
            sum += delta
            i += 2
        }
        return abs(sum - GeomUtil.PI) <= GeomUtil.EPS
    }

    public func checkMaekawa() -> Bool {
        abs(getLineTypeCount(LineType.mountain.rawValue) - getLineTypeCount(LineType.valley.rawValue)) == 2
    }

    public func addLine(_ oriLine: OriLine) {
        _lines.append(oriLine)
        let type = oriLine.type().rawValue
        if type >= lineTypeCount.count {
            let old = lineTypeCount
            lineTypeCount = (0...type).map { $0 < old.count ? old[$0] : 0 }
        }
        lineTypeCount[type] += 1
    }

    public func changeLineType(_ b: LineType, _ b2: LineType) {
        if b == b2 { return }
        let from = b.rawValue
        let to = b2.rawValue
        if to >= lineTypeCount.count {
            let old = lineTypeCount
            lineTypeCount = (0...to).map { $0 < old.count ? old[$0] : 0 }
        }
        lineTypeCount[from] -= 1
        lineTypeCount[to] += 1
    }

    // MARK: - Comparable

    public func compareTo(_ oriPoint: OriPoint) -> Int {
        if xKey == oriPoint.xKey {
            return Int(Int32(yKey - oriPoint.yKey).signum())
        }
        return Int(Int32(xKey - oriPoint.xKey).signum())
    }

    public static func < (lhs: OriPoint, rhs: OriPoint) -> Bool {
        lhs.compareTo(rhs) < 0
    }

    public static func == (lhs: OriPoint, rhs: OriPoint) -> Bool {
        lhs.equals(rhs)
    }

    public func copy() -> OriPoint {
        OriPoint(self)
    }

    open override func equals(_ obj: Any?) -> Bool {
        guard let oriPoint = obj as? OriPoint else { return false }
        return xKey == oriPoint.xKey && yKey == oriPoint.yKey
    }

    open override func hashCode() -> Int {
        Int(Int32(truncatingIfNeeded: xKey &* 31 &+ yKey))
    }

    public func getAllLineTypeCount() -> [Int] { lineTypeCount }

    public func getAllLinesOfType(_ b: LineType) -> [OriLine] {
        _lines.filter { $0.type() == b }
    }

    public func getLineTypeCount(_ b: Int) -> Int {
        guard b >= 0 && b < lineTypeCount.count else { return 0 }
        return lineTypeCount[b]
    }

    public func getLineTypeCount(_ b: LineType) -> Int {
        getLineTypeCount(b.rawValue)
    }

    public func getOccurrenceCount() -> Int { _lines.count }

    public func isFlatFoldable(_ list: [OriLine]?) -> Bool {
        let mountain = getLineTypeCount(LineType.mountain.rawValue)
        let valley = getLineTypeCount(LineType.valley.rawValue)
        let boundary = getLineTypeCount(LineType.boundary.rawValue)
        if boundary > 0 {
            return boundary == 2
        }
        if mountain + valley != 0 {
            return checkMaekawa() && checkKawasaki(list)
        }
        return true
    }

    /// Java `List.remove(Object)`: removes by equals (JS also checks identity first).
    public func removeLine(_ oriLine: OriLine) {
        if let index = _lines.firstIndex(where: { $0 === oriLine || $0.equals(oriLine) }) {
            _lines.remove(at: index)
        }
        let type = oriLine.type().rawValue
        if type < lineTypeCount.count {
            lineTypeCount[type] -= 1
        }
    }

    public func toFloatArray() -> [Float] {
        [Float(x), Float(y)]
    }

    open override func toString() -> String {
        "OriPoint([\(xKey), \(yKey)]: [\(JavaMath.numberDescription(x)), \(JavaMath.numberDescription(y))])"
    }
}
