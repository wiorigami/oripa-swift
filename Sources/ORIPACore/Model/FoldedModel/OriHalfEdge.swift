// Port of `com.origamitoolbox.oripa.model.foldedmodel.OriHalfEdge`
// (oripa-port src/js/core/model/foldedmodel/OriHalfEdge.js).
//
// Java `OriHalfEdge extends Segment<OriVertex>`; `lineType` keeps the Java byte values
// (1 = boundary, 2 = mountain, 3 = valley, same as the crease-pattern line types).
import Foundation

open class OriHalfEdge: Segment<OriVertex> {
    /// Java byte line type raw value (1 boundary / 2 mountain / 3 valley).
    public let lineType: Int

    /// Owning face (Java `public OriFace face`; weak here to break the face<->edge cycle).
    public weak var face: OriFace?

    /// Paired opposite half-edge (Java package-private `twin`; weak for the same reason).
    public weak var twin: OriHalfEdge?

    public init(_ start: OriVertex, _ end: OriVertex, _ lineType: Int) {
        self.lineType = lineType
        super.init(start, end)
    }

    // MARK: - Java equals/hashCode

    /// Java `equals(Object)`: vertex equality of start/end (line type is ignored).
    open override func equals(_ obj: Any?) -> Bool {
        guard let oriHalfEdge = obj as? OriHalfEdge else { return false }
        return start.equals(oriHalfEdge.start) && end.equals(oriHalfEdge.end)
    }

    /// Java `hashCode()`: `start.hashCode() * 31 + end.hashCode()`.
    open override func hashCode() -> Int {
        Int(Int32(truncatingIfNeeded: start.hashCode()) &* 31
            &+ Int32(truncatingIfNeeded: end.hashCode()))
    }

    open override func toString() -> String {
        "OriHalfEdge(\(start), \(end), \(lineType))"
    }
}
