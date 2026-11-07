// Port of `com.origamitoolbox.oripa.util.PointDouble` (oripa-port src/js/core/util/PointDouble.js).
//
// A class (not a struct) because the Java model hierarchy depends on subclassing:
// `OriVertex extends PointDouble`, `OriPoint extends PointDouble`.
import Foundation

open class PointDouble: JavaHashable, CustomStringConvertible {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    /// Java copy constructor: `new PointDouble(PointDouble)`.
    public init(_ pointDouble: PointDouble) {
        self.x = pointDouble.x
        self.y = pointDouble.y
    }

    /// Java `PointDouble.length(double, double)`.
    public static func length(_ d: Double, _ d2: Double) -> Double {
        hypot(d, d2)
    }

    /// Java `equals(Object)`: `Double.compare(x) == 0 && Double.compare(y) == 0`.
    /// The JS port compares with `===`; NaN is never equal there, so `==` is used here.
    open func equals(_ obj: Any?) -> Bool {
        guard let pointDouble = obj as? PointDouble else { return false }
        return x == pointDouble.x && y == pointDouble.y
    }

    public func getMinDistance(_ pointDouble: PointDouble) -> Double {
        GeomUtil.getDistance(self, pointDouble)
    }

    /// Java `hashCode()`: `(int)(bits(x) ^ (bits(x) >>> 32)) * 31 + (int)(bits(y) ^ ...)`.
    open func hashCode() -> Int {
        let hx = PointDouble.hashDouble(x)
        let hy = PointDouble.hashDouble(y)
        return Int(hx &* 31 &+ hy)
    }

    public func length() -> Double {
        PointDouble.length(x, y)
    }

    public func toString() -> String {
        "PointDouble(\(JavaMath.numberDescription(x)), \(JavaMath.numberDescription(y)))"
    }

    public var description: String { toString() }

    /// Java `Double.doubleToLongBits(d) ^ (>>> 32)` truncated to `int`; the JS port uses the
    /// canonical NaN bits `0x7fc00000` for NaN.
    @inline(__always)
    static func hashDouble(_ d: Double) -> Int32 {
        if d.isNaN { return Int32(bitPattern: 0x7fc0_0000) }
        let bits = d.bitPattern
        return Int32(truncatingIfNeeded: bits ^ (bits >> 32))
    }
}
