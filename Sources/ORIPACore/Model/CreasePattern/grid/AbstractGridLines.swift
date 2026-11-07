// Port of `com.origamitoolbox.oripa.model.creasepattern.grid.AbstractGridLines`
// (oripa-port src/js/core/model/creasepattern/grid/AbstractGridLines.js).
import Foundation

open class AbstractGridLines {
    private let _boxHalfSideLength: Float
    private let _divisionNumber: Int
    private var _renderData: GridRenderData

    public init(_ divisionNumber: Int, _ boxHalfSideLength: Float) {
        precondition(divisionNumber > 0 && boxHalfSideLength > 0.0,
                     "Parameters should be greater than 0")
        self._boxHalfSideLength = boxHalfSideLength
        self._divisionNumber = divisionNumber
        // Java calls the overridable `makeRenderData()` from the constructor; Swift needs every
        // stored property initialized first, so seed a placeholder and then dispatch.
        self._renderData = GridRenderData([], [], [])
        self._renderData = makeRenderData()
    }

    /// Abstract in Java; concrete subclasses implement the nearest-grid-line search.
    open func findLine(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriLine> {
        preconditionFailure("abstract: findLine")
    }

    public func getBoxHalfSideLength() -> Float { _boxHalfSideLength }
    public func getDivisionNumber() -> Int { _divisionNumber }
    public func getRenderData() -> GridRenderData { _renderData }

    open func makeRenderData() -> GridRenderData {
        preconditionFailure("abstract: makeRenderData")
    }
}
