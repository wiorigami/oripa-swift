// Small numeric helpers that reproduce Java/JS math semantics where Swift differs.
import Foundation

public enum JavaMath {
    /// JS `Math.round`: round half toward +infinity (`floor(x + 0.5)`), unlike Swift's
    /// `rounded()` which rounds half away from zero.
    @inline(__always)
    public static func round(_ value: Double) -> Double {
        (value + 0.5).rounded(.down)
    }

    /// Java/JS `String.valueOf(double)` for integral values (JS prints `3`, not `3.0`).
    /// Used by the debug `toString()` implementations to stay 1:1 with the reference output.
    public static func numberDescription(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value > 0 ? "Infinity" : "-Infinity" }
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }

    /// JS `Math.round(x) | 0`; non-finite values convert to 0 like the JS `| 0` operator
    /// (`Math.round(NaN) | 0 === 0`), matching Java `(int) Math.round(NaN) == 0`.
    @inline(__always)
    public static func roundToInt(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(Int32(truncatingIfNeeded: Int(round(value))))
    }
}
