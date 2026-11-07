// Port of `com.origamitoolbox.oripa.util.Segment<T extends PointDouble>`
// (oripa-port src/js/core/util/Segment.js).
import Foundation

open class Segment<T: PointDouble>: JavaHashable, CustomStringConvertible {
    public let start: T
    public let end: T

    public init(_ start: T, _ end: T) {
        self.start = start
        self.end = end
    }

    open func equals(_ obj: Any?) -> Bool {
        guard let segment = obj as? Segment<T> else { return false }
        return start.equals(segment.start) && end.equals(segment.end)
    }

    open func hashCode() -> Int {
        Int(Int32(truncatingIfNeeded: start.hashCode()) &* 31 &+ Int32(truncatingIfNeeded: end.hashCode()))
    }

    public func getMinDistance(_ pointDouble: PointDouble) -> Double {
        let minDistance = min(
            GeomUtil.getDistance(start, pointDouble),
            GeomUtil.getDistance(end, pointDouble)
        )
        return GeomUtil.isInRange(start, end, GeomUtil.getPerpendicularIntersect(start, end, pointDouble))
            ? min(minDistance, GeomUtil.getPerpendicularDistance(start, end, pointDouble))
            : minDistance
    }

    public func toString() -> String {
        "Segment(\(start.toString()), \(end.toString()))"
    }

    public var description: String { toString() }
}
