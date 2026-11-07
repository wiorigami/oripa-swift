// Port of `com.origamitoolbox.oripa.util.MinMaxDouble` (oripa-port src/js/core/util/MinMaxDouble.js).
import Foundation

public final class MinMaxDouble {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(_ minX: Double, _ minY: Double, _ maxX: Double, _ maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    /// Empty range: min = +MAX_VALUE, max = -MAX_VALUE.
    public init() {
        self.minX = Double.greatestFiniteMagnitude
        self.minY = Double.greatestFiniteMagnitude
        self.maxX = -Double.greatestFiniteMagnitude
        self.maxY = -Double.greatestFiniteMagnitude
    }

    /// Java `readArray(double[4])`.
    public static func readArray(_ values: [Double]) -> MinMaxDouble {
        precondition(values.count == 4, "array length must be 4")
        return MinMaxDouble(values[0], values[1], values[2], values[3])
    }

    public func getCenterX() -> Double { (minX + maxX) / 2.0 }
    public func getCenterY() -> Double { (minY + maxY) / 2.0 }
    public func getHalfSizeX() -> Double { maxX - getCenterX() }
    public func getHalfSizeY() -> Double { maxY - getCenterY() }
    public func getMaxHalfSize() -> Double { max(getHalfSizeX(), getHalfSizeY()) }
    public func toArray() -> [Double] { [minX, minY, maxX, maxY] }
}
