// Port of `com.origamitoolbox.oripa.model.renderdata.GLDataCpSimple`
// (oripa-port src/js/core/model/renderdata/GLDataCpSimple.js).
//
// Java encodings: float[] position arrays.
import Foundation

public enum GLDataCpSimple {
    /// `linesToFloats(Iterable<OriLine>)` -> [x0,y0,x1,y1, ...].
    public static func linesToFloats(_ lines: [OriLine]) -> [Float] {
        var out = [Float](repeating: 0, count: lines.count * 4)
        for (i, line) in lines.enumerated() {
            let p = i * 4
            out[p] = Float(line.start.x)
            out[p + 1] = Float(line.start.y)
            out[p + 2] = Float(line.end.x)
            out[p + 3] = Float(line.end.y)
        }
        return out
    }

    /// `pointsToFloats(Iterable<OriPoint>, boolean z, boolean z2)` — filters by line-type
    /// counts. Called with a single argument it behaves like the Java Collection overload
    /// (all points, no filtering), matching both call sites of GLDataCpSimple.
    public static func pointsToFloats(_ points: [OriPoint], _ z: Bool, _ z2: Bool) -> [Float] {
        var out: [Float] = []
        if z || z2 {
            for point in points {
                if z || point.getLineTypeCount(0) != 0 {
                    if z2 || point.getLineTypeCount(2) != 0 || point.getLineTypeCount(3) != 0 ||
                        point.getLineTypeCount(1) != 0 {
                        out.append(Float(point.x))
                        out.append(Float(point.y))
                    }
                }
            }
        }
        return out
    }

    /// `pointsToFloats(Collection<OriPoint>)` without filters (2-arg call site).
    public static func pointsToFloatsSimple(_ points: [OriPoint]) -> [Float] {
        var out = [Float](repeating: 0, count: points.count * 2)
        for (i, point) in points.enumerated() {
            out[i * 2] = Float(point.x)
            out[i * 2 + 1] = Float(point.y)
        }
        return out
    }
}
