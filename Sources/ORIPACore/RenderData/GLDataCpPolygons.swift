// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataCpPolygons`
// (oripa-port src/js/core/model/renderdata/GLDataCpPolygons.js).
//
// CP check polygons are shrunk 50% toward their centroid and fan-triangulated.
// Java encodings: pointArray float[], drawOrderArray short[].
import Foundation

public final class GLDataCpPolygons {
    public let pointArray: [Float]
    public let drawOrderArray: [Int]

    public init(_ pointArray: [Float], _ drawOrderArray: [Int]) {
        self.pointArray = pointArray
        self.drawOrderArray = drawOrderArray
    }

    public static func getRenderData(_ polygons: [OriPolygon]) -> GLDataCpPolygons {
        var pointCount = 0
        var indexCount = 0
        for polygon in polygons {
            let points = polygon.points
            pointCount += points.count
            indexCount += (points.count - 2) * 3
        }
        var pointArray = [Float](repeating: 0, count: pointCount * 2)
        var drawOrderArray = [Int](repeating: 0, count: indexCount)
        var pointBase = 0
        var indexBase = 0
        for polygon in polygons {
            let centroid = polygon.getCentroid()
            let n = polygon.points.count
            for j in 0..<n {
                let p = polygon.points[j]
                let k = (pointBase + j) * 2
                pointArray[k] = Float((p.x - centroid.x) * 0.5 + centroid.x)
                pointArray[k + 1] = Float((p.y - centroid.y) * 0.5 + centroid.y)
            }
            if n >= 3 {
                for j in 2..<n {
                    let o = indexBase + (j - 2) * 3
                    drawOrderArray[o] = pointBase
                    drawOrderArray[o + 1] = pointBase + j - 1
                    drawOrderArray[o + 2] = pointBase + j
                }
            }
            indexBase += (n - 2) * 3
            pointBase += n
        }
        return GLDataCpPolygons(pointArray, drawOrderArray)
    }
}
