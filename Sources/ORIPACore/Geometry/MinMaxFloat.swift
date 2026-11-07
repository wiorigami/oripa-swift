// Port of `com.origamitoolbox.oripa.util.MinMaxFloat` (oripa-port src/js/core/util/MinMaxFloat.js).
import Foundation

public final class MinMaxFloat {
    public var minX: Float
    public var minY: Float
    public var maxX: Float
    public var maxY: Float

    /// `Float.MAX_VALUE` / `-Float.MAX_VALUE` defaults (JS: 3.4028234663852886e38).
    public init() {
        self.minX = Float.greatestFiniteMagnitude
        self.minY = Float.greatestFiniteMagnitude
        self.maxX = -Float.greatestFiniteMagnitude
        self.maxY = -Float.greatestFiniteMagnitude
    }

    public init(_ minX: Float, _ minY: Float, _ maxX: Float, _ maxY: Float) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    /// Java `readArray(float[4])`.
    public static func readArray(_ values: [Float]) -> MinMaxFloat {
        precondition(values.count == 4, "array length must be 4")
        return MinMaxFloat(values[0], values[1], values[2], values[3])
    }

    public func getCenterX() -> Float { (minX + maxX) / 2.0 }
    public func getCenterY() -> Float { (minY + maxY) / 2.0 }
    public func getHalfSizeX() -> Float { maxX - getCenterX() }
    public func getHalfSizeY() -> Float { maxY - getCenterY() }
    public func getMaxHalfSize() -> Float { max(getHalfSizeX(), getHalfSizeY()) }
    public func toArray() -> [Float] { [minX, minY, maxX, maxY] }
}
