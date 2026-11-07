// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataLinesWidth`
// (oripa-port src/js/core/model/renderdata/GLDataLinesWidth.js).
//
// Each line becomes a quad (4 vertices, 2 triangles) whose vertex offset is encoded as an
// angle (tenths of a degree) applied in the GL vertex shader; Canvas renderers apply the
// same offsets in screen space.
// Java encodings: vertexPosition float[], vertexAngleDeg short[], drawOrder short[].
// Swift keeps the tenths-of-degree angle as a Float value.
import Foundation

public final class GLDataLinesWidth {
    public let vertexPosition: [Float]
    public let vertexAngleDeg: [Float]
    public let drawOrder: [Int]

    public init(_ vertexPosition: [Float], _ vertexAngleDeg: [Float], _ drawOrder: [Int]) {
        self.vertexPosition = vertexPosition
        self.vertexAngleDeg = vertexAngleDeg
        self.drawOrder = drawOrder
    }

    private static func getRenderDataRange(_ list: [OriLine], _ i: Int, _ i2: Int) -> GLDataLinesWidth {
        let count = i2 - i
        var vertexPosition = [Float](repeating: 0, count: count * 2 * 4)
        var vertexAngleDeg = [Float](repeating: 0, count: count * 4)
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
        }
        return GLDataLinesWidth(vertexPosition, vertexAngleDeg, drawOrder)
    }

    /// `getRenderData(OriLine | List<OriLine>)`.
    public static func getRenderData(_ line: OriLine?) -> GLDataLinesWidth {
        guard let line else { return getRenderDataRange([], 0, 0) }
        return getRenderDataRange([line], 0, 1)
    }

    public static func getRenderData(_ list: [OriLine]) -> GLDataLinesWidth {
        getRenderDataRange(list, 0, list.count)
    }

    public static func getRenderDataSplit(_ list: [OriLine]) -> [GLDataLinesWidth] {
        let size = list.count
        let maxLines = GLUtil.MAX_LINES_PER_SET
        let sets = min((size / maxLines) + (size % maxLines != 0 ? 1 : 0), 6)
        var result: [GLDataLinesWidth] = []
        for i in 0..<sets {
            let from = (size * i) / sets
            let to = (size * (i + 1)) / sets
            result.append(getRenderDataRange(list, from, to))
        }
        return result
    }
}
