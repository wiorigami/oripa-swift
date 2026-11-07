// Port of `com.origamitoolbox.oripa.model.creasepattern.OriLine`
// (oripa-port src/js/core/model/creasepattern/OriLine.js).
//
// Java `OriLine extends Segment<OriPoint>`; the constructor stores start/end ordered by
// `OriPoint.compareTo` unless `ignoreOrder` is set.
import Foundation

open class OriLine: Segment<OriPoint> {
    public static let STRIDE = 4

    private var _lineType: LineType

    public init(_ start: OriPoint, _ end: OriPoint, _ lineType: LineType) {
        self._lineType = lineType
        let ordered = start.compareTo(end) <= 0
        super.init(ordered ? start : end, ordered ? end : start)
    }

    public init(_ start: OriPoint, _ end: OriPoint, _ lineType: LineType, _ ignoreOrder: Bool) {
        self._lineType = lineType
        let ordered = ignoreOrder || start.compareTo(end) <= 0
        super.init(ordered ? start : end, ordered ? end : start)
    }

    /// Convenience for call sites that keep the Java `byte` line-type value.
    public convenience init(_ start: OriPoint, _ end: OriPoint, _ lineTypeValue: Int) {
        self.init(start, end, LineType(rawValue: lineTypeValue) ?? .undefined)
    }

    public convenience init(_ start: OriPoint, _ end: OriPoint, _ lineTypeValue: Int, _ ignoreOrder: Bool) {
        self.init(start, end, LineType(rawValue: lineTypeValue) ?? .undefined, ignoreOrder)
    }

    // MARK: - Line type

    /// Java `type()` (a byte in Java).
    public func type() -> LineType { _lineType }

    /// Raw Java `byte` value of the line type.
    public var typeValue: Int { _lineType.rawValue }

    /// Stored line type; assigning keeps the endpoint line-type counters consistent (`setType`).
    public var lineType: LineType {
        get { _lineType }
        set { setType(newValue) }
    }

    /// Java `setType(byte)`: updates the counters of both endpoints.
    public func setType(_ b: LineType) {
        start.changeLineType(_lineType, b)
        end.changeLineType(_lineType, b)
        _lineType = b
    }

    // MARK: - Geometry

    /// Java `containsInRange(OriPoint)` (integer key range).
    public func containsInRange(_ oriPoint: OriPoint) -> Bool {
        GeomUtil.isInRangeInt(start.xKey, end.xKey, oriPoint.xKey)
            && GeomUtil.isInRangeInt(start.yKey, end.yKey, oriPoint.yKey)
    }

    /// Java `copy()`: deep-copies both endpoints, preserving endpoint order.
    public func copy() -> OriLine {
        OriLine(start.copy(), end.copy(), _lineType, true)
    }

    /// Java `diagonalCopy()`: swaps the y coordinates of the endpoints.
    public func diagonalCopy() -> OriLine {
        OriLine(OriPoint(start.x, end.y), OriPoint(end.x, start.y), _lineType)
    }

    open override func equals(_ obj: Any?) -> Bool {
        guard let oriLine = obj as? OriLine else { return false }
        return start.equals(oriLine.start) && end.equals(oriLine.end)
    }

    open override func hashCode() -> Int {
        Int(Int32(truncatingIfNeeded: start.hashCode()) &* 31 &+ Int32(truncatingIfNeeded: end.hashCode()))
    }

    public func toFloatArray() -> [Float] {
        [Float(start.x), Float(start.y), Float(end.x), Float(end.y)]
    }

    open override func toString() -> String {
        "OriLine(\(start.toString()), \(end.toString()), \(LineType.getString(_lineType.rawValue) ?? "UNDEFINED"))"
    }
}
