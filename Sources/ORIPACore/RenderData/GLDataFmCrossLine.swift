// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataFmCrossLine`
// (oripa-port src/js/core/model/renderdata/GLDataFmCrossLine.js).
//
// For each folded face, intersects the cut line with the face outline, picks the longest
// chord, maps it back through the face transform matrix to crease-pattern coordinates
// (cpPosition) and keeps the raw cut line segment (fmPosition).
// Java encodings: cpPosition float[], fmPosition float[].
import Foundation

public final class GLDataFmCrossLine {
    public let cpPosition: [Float]
    public let fmPosition: [Float]

    public init(_ cpPosition: [Float], _ fmPosition: [Float]) {
        self.cpPosition = cpPosition
        self.fmPosition = fmPosition
    }

    public static func getRenderData(
        _ faces: [OriFace],
        _ crossLine: CrossLine,
        _ angleDeg: Int,
        _ position: Int
    ) -> GLDataFmCrossLine {
        let fmCrossLine = crossLine.getFmCrossLine(angleDeg: angleDeg, position: position)
        let fmPosition: [Float] = [
            Float(fmCrossLine.start.x), Float(fmCrossLine.start.y),
            Float(fmCrossLine.end.x), Float(fmCrossLine.end.y),
        ]
        var cpPosition: [Float] = []
        for face in faces {
            var points: [OriPoint] = []
            var seen = Set<String>()
            for halfEdge in face.halfEdges {
                guard let start = halfEdge.start.valueAfterFold,
                      let end = halfEdge.end.valueAfterFold else { continue }
                guard let hit = GeomUtil.getSegmentIntersect(fmCrossLine.start, fmCrossLine.end, start, end) else {
                    continue
                }
                let key = crossLineKey(hit)
                if !seen.contains(key) {
                    seen.insert(key)
                    points.append(OriPoint(hit.x, hit.y))
                }
            }
            var segment: Segment<PointDouble>? = nil
            if points.count == 2 {
                if points[0].getMinDistance(points[1]) >= GeomUtil.EPS {
                    segment = Segment<PointDouble>(points[0], points[1])
                }
            } else if points.count > 2 {
                var maxDistance = -Double.greatestFiniteMagnitude
                for j in 0..<(points.count - 1) {
                    for k in (j + 1)..<points.count {
                        let distance = points[j].getMinDistance(points[k])
                        if distance > maxDistance {
                            maxDistance = distance
                            segment = Segment<PointDouble>(points[j], points[k])
                        }
                    }
                }
                if maxDistance < GeomUtil.EPS { segment = nil }
            }
            if let segment {
                // The JS reference calls GLUtil.getObjectPointFromWorldPointFloat(matrix, x, y)
                // with full JS-number (double) segment coordinates; only the matrix is float32.
                // Using the Double overload keeps the CP cut-line coordinates 1:1 with it.
                let matrix = face.transformMatrix.map { Double($0) }
                let start = GLUtil.getObjectPointFromWorldPointDouble(matrix, segment.start.x, segment.start.y)
                let end = GLUtil.getObjectPointFromWorldPointDouble(matrix, segment.end.x, segment.end.y)
                cpPosition.append(Float(start.x))
                cpPosition.append(Float(start.y))
                cpPosition.append(Float(end.x))
                cpPosition.append(Float(end.y))
            }
        }
        return GLDataFmCrossLine(cpPosition, fmPosition)
    }

    /// JS key: `Math.round(hit.x * 1000) + ":" + Math.round(hit.y * 1000)`.
    private static func crossLineKey(_ hit: PointDouble) -> String {
        // JS Math.round: round half towards +Infinity (floor(x + 0.5)).
        let x = (hit.x * 1000 + 0.5).rounded(.down)
        let y = (hit.y * 1000 + 0.5).rounded(.down)
        return "\(x):\(y)"
    }
}
