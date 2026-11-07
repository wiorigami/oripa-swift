// Port of `com.origamitoolbox.oripa.model.foldedmodel.OriVertex`
// (oripa-port src/js/core/model/foldedmodel/OriVertex.js).
//
// Java `OriVertex extends PointDouble`. `x`/`y` are the crease-pattern coordinates copied from
// the polygon point; `valueAfterFold` is filled by `FoldedModel.foldWithoutOverlap`.
// Equality/hashCode use the quantized `OriPoint.getKey` coordinate keys, not exact coordinates.
import Foundation

open class OriVertex: PointDouble {
    public static let STRIDE = 2

    public let index: Int

    /// Folded 2D position; `nil` until the fold walk reaches this vertex (Java `null`).
    public var valueAfterFold: PointDouble?

    /// Java `OriVertex(PointDouble, int)`: copies x/y, no valueAfterFold yet.
    public init(point: PointDouble, index: Int) {
        self.index = index
        self.valueAfterFold = nil
        super.init(point.x, point.y)
    }

    /// Java-style convenience for the same constructor.
    public convenience init(_ point: PointDouble, _ index: Int) {
        self.init(point: point, index: index)
    }

    // MARK: - Java equals/hashCode

    /// Java `equals(Object)`: OriVertex-only, coordinate-key equality.
    open override func equals(_ obj: Any?) -> Bool {
        guard let oriVertex = obj as? OriVertex else { return false }
        return OriPoint.getKey(x) == OriPoint.getKey(oriVertex.x)
            && OriPoint.getKey(y) == OriPoint.getKey(oriVertex.y)
    }

    /// Java `hashCode()`: `(OriPoint.getKey(x) * 31) + OriPoint.getKey(y)` as an int.
    open override func hashCode() -> Int {
        Int(Int32(truncatingIfNeeded: OriPoint.getKey(x)) &* 31
            &+ Int32(truncatingIfNeeded: OriPoint.getKey(y)))
    }

    open override func toString() -> String {
        "OriVertex(\(x), \(y)): \(index)"
    }
}
