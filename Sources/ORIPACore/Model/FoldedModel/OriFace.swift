// Port of `com.origamitoolbox.oripa.model.foldedmodel.OriFace`
// (oripa-port src/js/core/model/foldedmodel/OriFace.js).
//
// One face of the folded model. `transformMatrix` is the 4x4 column-major fold matrix that maps
// the face's crease-pattern coordinates to folded coordinates (Android `float[16]`).
import Foundation

public final class OriFace: CustomStringConvertible {
    public let index: Int
    public var halfEdges: [OriHalfEdge]
    /// Column-major `float[16]`; identity/transform assigned by `FoldedModel`.
    public var transformMatrix: [Float]
    public var isCCWOrientation: Bool

    public init(_ index: Int) {
        self.index = index
        self.halfEdges = []
        self.transformMatrix = [Float](repeating: 0, count: 16)
        self.isCCWOrientation = false
    }

    public func toString() -> String { String(index) }

    public var description: String { toString() }
}
