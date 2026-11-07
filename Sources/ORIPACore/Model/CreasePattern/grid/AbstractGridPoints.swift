// Port of `com.origamitoolbox.oripa.model.creasepattern.grid.AbstractGridPoints`
// (oripa-port src/js/core/model/creasepattern/grid/AbstractGridPoints.js).
import Foundation

open class AbstractGridPoints {
    private let _divisionNumber: Int

    public init(_ divisionNumber: Int) {
        self._divisionNumber = divisionNumber
    }

    /// Abstract in Java; concrete subclasses implement the nearest-grid-point search.
    open func findPoint(_ pointDouble: PointDouble, _ d: Double, _ d2: Double) -> NearestItem<OriPoint> {
        preconditionFailure("abstract: findPoint")
    }

    public func getDivisionNumber() -> Int { _divisionNumber }
}
