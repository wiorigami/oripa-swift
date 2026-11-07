// Port of `com.origamitoolbox.oripa.model.creasepattern.OriPolygon`
// (oripa-port src/js/core/model/creasepattern/OriPolygon.js).
import Foundation

open class OriPolygon {
    /// Polygon vertices (Java `final List<OriPoint>`; mutated by the face-extraction loop).
    public var points: [OriPoint]
    /// Line type (Java byte value) of the edge that starts at the matching `points` entry.
    public var lineTypes: [Int]

    public init() {
        self.points = []
        self.lineTypes = []
    }

    public init(_ points: [OriPoint], _ lineTypes: [Int]) {
        self.points = points
        self.lineTypes = lineTypes
    }

    /// Java package-private `getArea()` (shoelace formula).
    public func getArea() -> Double {
        var area = 0.0
        var size = points.count - 1
        for i in 0..<points.count {
            area += (points[size].x * points[i].y) - (points[i].x * points[size].y)
            size = i
        }
        return area / 2.0
    }

    public func getCentroid() -> PointDouble {
        var sumX = 0.0
        var sumY = 0.0
        for point in points {
            sumX += point.x
            sumY += point.y
        }
        let size = Double(points.count)
        return PointDouble(sumX / size, sumY / size)
    }

    public func toString() -> String {
        var text = "OriPolygon("
        for i in 0..<points.count {
            text += LineType.getString(lineTypes[i]) ?? "UNDEFINED"
            text += ": "
            text += points[i].toString()
            text += ","
        }
        text += ")"
        return text
    }
}
