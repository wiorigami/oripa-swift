// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataCpLinesTypedWidth`
// (oripa-port src/js/core/model/renderdata/GLDataCpLinesTypedWidth.js).
//
// Quad per line: 4 vertices, angle offset in tenths of degrees, line distance for dashed
// patterns, per-vertex line type byte.
// Java encodings: vertexPosition float[], vertexAngleDeg short[], lineDistance float[],
// vertexType byte[], drawOrder short[]. Swift: angles are kept as Float values holding
// tenths of a degree (renderer divides by 10).
import Foundation

public final class GLDataCpLinesTypedWidth {
    public let vertexPosition: [Float]
    public let vertexAngleDeg: [Float]
    public let lineDistance: [Float]
    public let vertexType: [UInt8]
    public let drawOrder: [Int]

    public init(
        _ vertexPosition: [Float],
        _ vertexAngleDeg: [Float],
        _ lineDistance: [Float],
        _ vertexType: [UInt8],
        _ drawOrder: [Int]
    ) {
        self.vertexPosition = vertexPosition
        self.vertexAngleDeg = vertexAngleDeg
        self.lineDistance = lineDistance
        self.vertexType = vertexType
        self.drawOrder = drawOrder
    }

    private static func getRenderDataRange(_ list: [OriLine], _ i: Int, _ i2: Int) -> GLDataCpLinesTypedWidth {
        let count = i2 - i
        var vertexPosition = [Float](repeating: 0, count: count * 2 * 4)
        var vertexAngleDeg = [Float](repeating: 0, count: count * 4)
        var lineDistance = [Float](repeating: 0, count: count * 4)
        var vertexType = [UInt8](repeating: 0, count: count * 4)
        var drawOrder = [Int](repeating: 0, count: count * 6)
        for k in 0..<count {
            let line = list[i + k]
            let v = k * 4
            let p = v * 2
            let sx = line.start.x, sy = line.start.y, ex = line.end.x, ey = line.end.y
            vertexPosition[p] = Float(sx)
            vertexPosition[p + 1] = Float(sy)
            vertexPosition[p + 2] = Float(sx)
            vertexPosition[p + 3] = Float(sy)
            vertexPosition[p + 4] = Float(ex)
            vertexPosition[p + 5] = Float(ey)
            vertexPosition[p + 6] = Float(ex)
            vertexPosition[p + 7] = Float(ey)
            let o = k * 6
            drawOrder[o] = v
            drawOrder[o + 1] = v + 1
            drawOrder[o + 2] = v + 3
            drawOrder[o + 3] = v + 1
            drawOrder[o + 4] = v + 2
            drawOrder[o + 5] = v + 3
            let angle = atan2(ey - sy, ex - sx)
            let degPlus = jsTruncate((angle + Double.pi / 2) * 180 / Double.pi * 10)
            let degMinus = jsTruncate((angle - Double.pi / 2) * 180 / Double.pi * 10)
            vertexAngleDeg[v] = Float(degPlus)
            vertexAngleDeg[v + 1] = Float(degMinus)
            vertexAngleDeg[v + 2] = Float(degMinus)
            vertexAngleDeg[v + 3] = Float(degPlus)
            let dx = ex - sx
            let dy = ey - sy
            let distance = (dx * dx + dy * dy).squareRoot()
            lineDistance[v] = 0
            lineDistance[v + 1] = 0
            lineDistance[v + 2] = Float(distance)
            lineDistance[v + 3] = Float(distance)
            let t = line.type().rawValue
            for m in 0..<4 { vertexType[v + m] = UInt8(truncatingIfNeeded: t) }
        }
        return GLDataCpLinesTypedWidth(vertexPosition, vertexAngleDeg, lineDistance, vertexType, drawOrder)
    }

    /// `getRenderDataSplit(Iterable<OriLine>, boolean z, boolean z2)`:
    /// split into at most 6 GL shape sets (16-bit index buffers on Android).
    public static func getRenderDataSplit(_ iterable: [OriLine], _ z: Bool, _ z2: Bool) -> [GLDataCpLinesTypedWidth] {
        var filtered: [OriLine] = []
        filtered.reserveCapacity(iterable.count)
        for line in iterable {
            let t = line.type().rawValue
            if (z && z2) || (z && (t == 2 || t == 3 || t == 1)) || (z2 && t == 0) {
                filtered.append(line)
            }
        }
        let size = filtered.count
        let maxLines = GLUtil.MAX_LINES_PER_SET
        let sets = min((size / maxLines) + (size % maxLines != 0 ? 1 : 0), 6)
        var result: [GLDataCpLinesTypedWidth] = []
        for i in 0..<sets {
            let from = (size * i) / sets
            let to = (size * (i + 1)) / sets
            result.append(getRenderDataRange(filtered, from, to))
        }
        return result
    }
}

/// JS `x | 0`: truncate toward zero to a 32-bit two's-complement integer.
@inline(__always)
func jsTruncate(_ value: Double) -> Int {
    if value.isNaN { return 0 }
    let truncated = value.rounded(.towardZero)
    if truncated >= 2147483647 { return 2147483647 }
    if truncated <= -2147483648 { return -2147483648 }
    return Int(truncated)
}
